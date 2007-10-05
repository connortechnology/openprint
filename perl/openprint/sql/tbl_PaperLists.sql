DROP SEQUENCE PaperList_Index_Seq;
CREATE SEQUENCE  PaperList_Index_Seq;
DROP TABLE tbl_PaperLists;
CREATE TABLE tbl_PaperLists (
	lngIndex		INT4 NOT NULL DEFAULT nextval('PaperList_Index_Seq'),
	strName			TEXT,
	strDescription	TEXT,
	PRIMARY KEY (lngIndex)
);
