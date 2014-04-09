﻿module internal LibGet.Driver 

open System
open System.IO
open System.Net
open System.Net.Cache
open System.Text.RegularExpressions
open System.Collections.Generic
open Config
open ICSharpCode.SharpZipLib
open ICSharpCode.SharpZipLib.Core
open ICSharpCode.SharpZipLib.Zip
open ICSharpCode.SharpZipLib.GZip

let buf_size   = 1310172
let (dataBuffer: byte array) = Array.zeroCreate buf_size

let re_numbers = Regex("\s*([0-9]+)-([0-9]+).zip",RegexOptions.Compiled ||| RegexOptions.IgnoreCase)
let re_fb2     = Regex("[0-9]+\.fb2",RegexOptions.Compiled ||| RegexOptions.IgnoreCase)

let library = ref "flibusta"
let retry   = ref 3
let nosql   = ref false
let fb2only = ref false
let verbose = ref false
let dest    = ref Environment.CurrentDirectory
let destsql = ref (Path.Combine(Environment.CurrentDirectory, String.Format("{0}_{1:yyyyMMdd_hhmmss}", !library, DateTime.Now)))
let config  = ref (Path.Combine(Environment.CurrentDirectory, "libget.conf"))
let usage   = [ "--library", CommandLine.ArgType.String(fun s -> library := s), "(flibusta) name of the library profile";
                "--retry",   CommandLine.ArgType.Int(fun s -> retry := s),      "(3) number of re-tries";
                "--nosql",   CommandLine.ArgType.Set(nosql),                    "(false) do not download database";
                "--fb2only", CommandLine.ArgType.Set(fb2only),                  "(false) clean non-FB2 entries from downloaded archives";
                "--to",      CommandLine.ArgType.String(fun s -> dest := s),    "(current directory) archives destination directory"; 
                "--tosql",   CommandLine.ArgType.String(fun s -> destsql := s), "(current directory) database destination directory"; 
                "--config",  CommandLine.ArgType.String(fun s -> config := s),  "(libget.conf) configuration file"; 
                "--verbose", CommandLine.ArgType.Set(verbose),                  "(false) print complete error information";
              ] |> List.map (fun (sh, ty, desc) -> CommandLine.ArgInfo(sh, ty, desc))
let usageText = "\nTool to download library updates\nVersion 1.5\n\nUsage: libget.exe [options]\n"

exception BadArchive of string

let nukeFile file =
    try File.Delete file with _ -> ()

let testZip (tmp: string) = 
    use z = new ZipFile (tmp)
    match z.TestArchive true with 
    | false -> raise(BadArchive("\tDownloaded archive is corrupted!"))
    | true  -> printfn "\tDownloaded archive is OK - integrity test passed"

let fromZip (s: ZipInputStream) : seq<ZipEntry> = 
    seq { let deleted = ref 0
          let overall = ref 0
          let e = ref (s.GetNextEntry())
          while (!e <> null) do
             if (!e).IsFile && re_fb2.IsMatch((!e).Name,0) then 
                overall := !overall + 1
                yield !e 
             else 
                overall := !overall + 1
                deleted := !deleted + 1
             e := s.GetNextEntry() 
          printfn "\tDownloaded archive cleaning - %d entries out of %d deleted" !deleted !overall }    

let cleanZip (tmp: string, file: string) =
    use si = new ZipInputStream(File.OpenRead(tmp))
    use so = new ZipOutputStream(File.Create(file))
    so.SetLevel(9)
    so.UseZip64 <- UseZip64.Dynamic
    fromZip si |> Seq.iter (fun elem -> let e = new ZipEntry(elem.Name)
                                        e.DateTime <- elem.DateTime
                                        so.PutNextEntry e
                                        StreamUtils.Copy(si, so, dataBuffer))
    so.Finish()
    so.Close()
    si.Close()

let processZip (tmp: string, file: string) = 
    try
       testZip tmp
       if !fb2only then cleanZip  (tmp, file)
       else             File.Move (tmp, file)
    with
    | _ -> nukeFile tmp; 
           reraise()

let processGz (tmp: string, file: string) =
    try
       use s  = new GZipInputStream(File.OpenRead(tmp))
       use fs = File.Create(Path.ChangeExtension(file,null))
       StreamUtils.Copy(s, fs, dataBuffer)
    with
    | _ -> nukeFile tmp; 
           reraise()

let processFile tmp file =
    match (Path.GetExtension file).ToLower() with
    | ".zip" -> processZip (tmp, file)
                nukeFile tmp
                1
    | ".gz"  -> processGz (tmp, file)
                nukeFile tmp
                1
    | _      -> printfn "\tUnknown file extension, ignoring \"%s\"" (Path.GetFileName file)
                nukeFile tmp
                0

let rec fetchFile (client: WebClient, url: Uri, file: string, attempt, temp:Option<string> ) = 
    let tmp = match temp with
              | None -> Path.GetTempFileName()
              | Some t -> t
    try
       printfn "Downloading file \"%s\" (#%d)" url.AbsoluteUri attempt
       client.DownloadFile (url, tmp)
       processFile tmp file
    with 
    | :? WebException -> if attempt < !retry then 
                            fetchFile(client, url, file, attempt + 1, Some tmp) 
                         else 
                            nukeFile tmp
                            reraise()   

let rec fetchStr(client: WebClient, url: Uri, attempt) = 
    try
       printfn "Downloading index for \"%s\" (#%d) " url.AbsoluteUri attempt
       client.DownloadString url
    with 
    | :? WebException -> if attempt < !retry then fetchStr(client, url, attempt + 1) else reraise()

let rec getArchives dir =
        seq { yield! Directory.EnumerateFiles(dir, "*.zip") |> Seq.map (fun (name) -> Path.GetFileName(name)) 
              for d in Directory.EnumerateDirectories(dir) do
                 yield! getArchives d }

let getLinks client (pattern:Regex) url =
   let index = fetchStr(client, url, 1)
   let matches = pattern.Matches(index)
   let matchToUrl (urlMatch : Match) = urlMatch.Groups.Item(1).Value
   matches |> Seq.cast |> Seq.map matchToUrl

[<EntryPoint>]
let main args = 
   if Array.isEmpty args then
      CommandLine.ArgParser.Usage (usage, usageText)
      exit 0
   CommandLine.ArgParser.Parse (usage, usageText=usageText)
   try 
      let conf = (getConfig !config).libraries |> Array.find (fun r -> r.name = !library)
      printfn "\nProcessing library \"%s\"\n" conf.name

      use client = new WebClient()
      client.CachePolicy <- new RequestCachePolicy(RequestCacheLevel.BypassCache)
      client.Headers.Add("user-agent", "Mozilla/5.0 (Windows; en-US)")

      let disect s =
         let m = re_numbers.Match(s)
         (Convert.ToInt32(m.Groups.Item(1).Value), Convert.ToInt32(m.Groups.Item(2).Value))
      let last_book = getArchives !dest |> Seq.fold (fun acc elem -> if acc < snd (disect elem) then snd (disect elem) else acc) 0 
      let new_links = getLinks client (Regex(conf.pattern, RegexOptions.Compiled ||| RegexOptions.IgnoreCase)) (new Uri(conf.url)) |> 
                        Seq.choose (fun elem -> if last_book < fst (disect elem) then Some(elem) else None )

      // Downloading archives
      let len = new_links |> Seq.fold (fun acc elem -> acc + fetchFile(client,(new Uri(Path.Combine(conf.url, elem))),(Path.Combine(!dest, elem)),1,None)) 0
      printfn "\nProcessed %d new archive(s)\n" len

      if !nosql then exit len

      // Downloading tables
      destsql := Path.GetFullPath(!destsql)
      let tables = getLinks client (Regex(conf.patternSQL, RegexOptions.Compiled ||| RegexOptions.IgnoreCase)) (new Uri(conf.urlSQL))
      if not (Seq.isEmpty tables) && not (Directory.Exists !destsql) then
         Directory.CreateDirectory !destsql |> ignore
      let tabs = tables |> Seq.fold (fun acc elem -> acc + fetchFile(client,(new Uri(Path.Combine(conf.urlSQL, elem))),(Path.Combine(!destsql, elem)),1,None)) 0
      printfn "\nProcessed database (%d tables)\n" tabs

      exit len
   with 
   | :? KeyNotFoundException as ex -> Console.Error.WriteLine("\nUnable to find configuration record for library: " + !library)
                                      if !verbose then Console.Error.WriteLine(ex.ToString())
                                      Console.Error.Flush()
                                      exit -1
   | :? WebException as ex         -> Console.Error.WriteLine("\nCommunication error: " + ex.Message)
                                      if !verbose then Console.Error.WriteLine(ex.ToString())
                                      Console.Error.Flush()
                                      exit -2
   | ex                            -> Console.Error.WriteLine("\nUnexpected error: " + ex.Message)
                                      if !verbose then Console.Error.WriteLine(ex.ToString())
                                      Console.Error.Flush()
                                      exit -3                                        