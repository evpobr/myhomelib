-------------------------------------------------------------------------------
--
-- MyHomeLib
--
-- Copyright (C) 2008-2010 Aleksey Penkov
--
-- Author(s)           eg
--                     Nick Rymanov    nrymanov@gmail.com
-- Created             04.09.2010
-- Description
--
-- Id: unit_Database_SQLite.pas 764 2010-09-15 14:01:35Z eg_ $
--
-- History
--
-------------------------------------------------------------------------------

DROP TABLE IF EXISTS Settings;
--@@

DROP TABLE IF EXISTS Series;
--@@

DROP TABLE IF EXISTS Genres;
--@@

DROP TABLE IF EXISTS Authors;
--@@

DROP TABLE IF EXISTS Books;
--@@

DROP TABLE IF EXISTS Genre_List;
--@@

DROP TABLE IF EXISTS Author_List;
--@@

CREATE TABLE Settings (
  SettingID    INTEGER NOT NULL PRIMARY KEY,
  SettingValue BLOB
);
--@@

CREATE TABLE Series (
  SeriesID          INTEGER     NOT NULL                       PRIMARY KEY AUTOINCREMENT,
  SeriesTitle       VARCHAR(80) NOT NULL COLLATE SYSTEM_NOCASE UNIQUE,
  SearchSeriesTitle VARCHAR(80)          COLLATE NOCASE
);
--@@

CREATE INDEX IXSeries_Title ON Series (SeriesTitle);
--@@

CREATE INDEX IXSeries_SearchSeriesTitle ON Series (SearchSeriesTitle);
--@@

CREATE TRIGGER TRSeries_AI AFTER INSERT ON Series
  BEGIN
    UPDATE Series
    SET SearchSeriesTitle = UPPER(NEW.SeriesTitle)
    WHERE SeriesID = NEW.SeriesID;
  END;
--@@

CREATE TRIGGER TRSeries_AU AFTER UPDATE ON Series
  BEGIN
    UPDATE Series
    SET SearchSeriesTitle = UPPER(NEW.SeriesTitle)
    WHERE SeriesID = NEW.SeriesID;
  END;
--@@

CREATE TABLE Genres (
  GenreCode  VARCHAR(20) NOT NULL COLLATE NOCASE PRIMARY KEY,
  ParentCode VARCHAR(20)          COLLATE NOCASE,
  FB2Code    VARCHAR(20)          COLLATE NOCASE,
  GenreAlias VARCHAR(50) NOT NULL COLLATE SYSTEM_NOCASE
);
--@@

CREATE UNIQUE INDEX IXGenres_ParentCode_GenreCode ON Genres (ParentCode, GenreCode);
--@@

CREATE INDEX IXGenres_FB2Code ON Genres (FB2Code);
--@@

CREATE INDEX IXGenres_GenreAlias ON Genres (GenreAlias);
--@@

CREATE TABLE Authors (
  AuthorID   INTEGER      NOT NULL                       PRIMARY KEY AUTOINCREMENT,
  LastName   VARCHAR(128) NOT NULL COLLATE SYSTEM_NOCASE,
  FirstName  VARCHAR(128)          COLLATE SYSTEM_NOCASE,
  MiddleName VARCHAR(128)          COLLATE SYSTEM_NOCASE,
  SearchName VARCHAR(512)          COLLATE NOCASE
);
--@@

CREATE INDEX IXAuthors_FullName ON Authors (LastName, FirstName, MiddleName);
--@@

CREATE INDEX IXAuthors_SearchName ON Authors (SearchName);
--@@

CREATE TRIGGER TRAuthors_AI AFTER INSERT ON Authors
  BEGIN
    UPDATE Authors
    SET SearchName = UPPER(NEW.LastName) || CASE WHEN IFNULL(NEW.FirstName,'')='' THEN '' ELSE ' ' END || UPPER(IFNULL(NEW.FirstName, '')) || CASE WHEN IFNULL(NEW.MiddleName,'') = '' THEN '' ELSE ' ' END || UPPER(IFNULL(NEW.MiddleName, ''))
    WHERE AuthorID = NEW.AuthorID ;
  END;
--@@

CREATE TRIGGER TRAuthors_AU AFTER UPDATE ON Authors
  BEGIN
    UPDATE Authors
    SET SearchName = UPPER(NEW.LastName) || CASE WHEN IFNULL(NEW.FirstName,'')='' THEN '' ELSE ' ' END || UPPER(IFNULL(NEW.FirstName, '')) || CASE WHEN IFNULL(NEW.MiddleName,'') = '' THEN '' ELSE ' ' END || UPPER(IFNULL(NEW.MiddleName, ''))
    WHERE AuthorID = NEW.AuthorID ;
  END;
--@@

CREATE TABLE Books (
  BookID           INTEGER      NOT NULL                       PRIMARY KEY AUTOINCREMENT,
  LibID            INTEGER      NOT NULL,
  Title            VARCHAR(150) NOT NULL COLLATE SYSTEM_NOCASE,
  SeriesID         INTEGER,
  SeqNumber        INTEGER,
  UpdateDate       VARCHAR(23)  NOT NULL,
  LibRate          INTEGER      NOT NULL                       DEFAULT 0,
  Lang             VARCHAR(2)            COLLATE SYSTEM_NOCASE,
  Folder           VARCHAR(200)          COLLATE SYSTEM_NOCASE,
  FileName         VARCHAR(170) NOT NULL COLLATE SYSTEM_NOCASE,
  InsideNo         INTEGER      NOT NULL,
  Ext              VARCHAR(10)           COLLATE SYSTEM_NOCASE,
  BookSize         INTEGER,
  Code             INTEGER      NOT NULL                       DEFAULT 0,
  IsLocal          INTEGER      NOT NULL                       DEFAULT 0,
  IsDeleted        INTEGER      NOT NULL                       DEFAULT 0,
  KeyWords         VARCHAR(255)          COLLATE SYSTEM_NOCASE,
  Rate             INTEGER      NOT NULL                       DEFAULT 0,
  Progress         INTEGER      NOT NULL                       DEFAULT 0,
  Annotation       VARCHAR(4096)         COLLATE SYSTEM_NOCASE,
  Review           BLOB,
  SearchTitle      VARCHAR(150)          COLLATE NOCASE,
  SearchLang       VARCHAR(2)            COLLATE NOCASE,
  SearchFolder     VARCHAR(200)          COLLATE NOCASE,
  SearchFileName   VARCHAR(170)          COLLATE NOCASE,
  SearchExt        VARCHAR(10)           COLLATE NOCASE,
  SearchKeyWords   VARCHAR(255)          COLLATE NOCASE,
  SearchAnnotation VARCHAR(4096)         COLLATE NOCASE
);
--@@

CREATE INDEX IXBooks_SeriesID_SeqNumber ON Books (SeriesID, SeqNumber);
--@@

CREATE INDEX IXBooks_SeriesID_IsDeleted_IsLocal ON Books (SeriesID, IsDeleted, IsLocal);
--@@

CREATE INDEX IXBooks_Title ON Books (Title);
--@@

CREATE INDEX IXBooks_FileName ON Books (FileName);
--@@

CREATE INDEX IXBooks_Folder ON Books (Folder);
--@@

CREATE INDEX IXBooks_IsDeleted ON Books (IsDeleted);
--@@

CREATE INDEX IXBooks_UpdateDate ON Books (UpdateDate);
--@@

CREATE INDEX IXBooks_IsLocal ON Books (IsLocal);
--@@

CREATE INDEX IXBooks_LibID ON Books (LibID);
--@@

CREATE INDEX IXBooks_KeyWords ON Books (KeyWords);
--@@

CREATE INDEX IXBooks_BookID_IsDeleted_IsLocal ON Books (BookID, IsDeleted, IsLocal);
--@@

CREATE INDEX IXBooks_SearchTitle ON Books (SearchTitle);
--@@

CREATE INDEX IXBooks_SearchLang ON Books (SearchLang);
--@@

CREATE INDEX IXBooks_SearchFolder ON Books (SearchFolder);
--@@

CREATE INDEX IXBooks_SearchFileName ON Books (SearchFileName);
--@@

CREATE INDEX IXBooks_SearchExt ON Books (SearchExt);
--@@

CREATE INDEX IXBooks_SearchKeyWords ON Books (SearchKeyWords);
--@@

CREATE INDEX IXBooks_SearchAnnotation ON Books (SearchAnnotation);
--@@

CREATE TRIGGER TRBooks_AI AFTER INSERT ON Books
  BEGIN
    UPDATE Books
    SET
      SearchTitle      = UPPER(NEW.Title),
      SearchLang       = UPPER(NEW.Lang),
      SearchFolder     = UPPER(NEW.Folder),
      SearchFileName   = UPPER(NEW.FileName),
      SearchExt        = UPPER(NEW.Ext),
      SearchKeyWords   = UPPER(NEW.KeyWords),
      SearchAnnotation = UPPER(NEW.Annotation)
    WHERE
      BookID = NEW.BookID;
  END;
--@@

CREATE TRIGGER TRBooks_AU AFTER UPDATE OF Title, Lang, Folder, FileName, Ext, KeyWords, Annotation ON Books
  BEGIN
    UPDATE Books
    SET
      SearchTitle      = UPPER(NEW.Title),
      SearchLang       = UPPER(NEW.Lang),
      SearchFolder     = UPPER(NEW.Folder),
      SearchFileName   = UPPER(NEW.FileName),
      SearchExt        = UPPER(NEW.Ext),
      SearchKeyWords   = UPPER(NEW.KeyWords),
      SearchAnnotation = UPPER(NEW.Annotation)
    WHERE
      BookID = NEW.BookID;
  END;
--@@

CREATE TRIGGER TRBooks_BD BEFORE DELETE ON Books
  BEGIN
    DELETE FROM Genre_List WHERE BookID = OLD.BookID;
    DELETE FROM Author_List WHERE BookID = OLD.BookID;
    DELETE FROM Series WHERE SeriesID IN (SELECT b.SeriesID FROM Books b WHERE  b.SeriesID = OLD.SeriesID GROUP BY b.SeriesID HAVING COUNT(b.SeriesID) <= 1);
    DELETE FROM Authors WHERE NOT AuthorID in (SELECT DISTINCT al.AuthorID FROM Author_List al);
  END;
--@@

CREATE TABLE Genre_List (
  GenreCode VARCHAR(20) NOT NULL,
  BookID    INTEGER     NOT NULL,

  CONSTRAINT "PKGenreList" PRIMARY KEY (BookID, GenreCode)
);
--@@

CREATE INDEX IXGenreList_GenreCode_BookID ON Genre_List (GenreCode, BookID);
--@@

CREATE TABLE Author_List (
  AuthorID INTEGER NOT NULL,
  BookID   INTEGER NOT NULL,

  CONSTRAINT "PKAuthorList" PRIMARY KEY (BookID, AuthorID)
);
--@@

CREATE INDEX IXAuthorList_AuthorID_BookID ON Author_List (AuthorID, BookID);
--@@
