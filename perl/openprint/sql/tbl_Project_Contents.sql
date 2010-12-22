DROP SEQUENCE IF EXISTS ContentsServiceIndex_seq;
CREATE SEQUENCE ContentsServiceIndex_seq;
DROP TABLE IF EXISTS tbl_Project_Contents;

CREATE TABLE tbl_Project_Contents (
	lngProjectIndex	INTEGER NOT NULL,		/* Index into the Projects table, which identifies the project that the contents belong to */
FOREIGN KEY (lngProjectIndex) REFERENCES Projects (Id),
	lngServiceIndex INTEGER NOT NULL DEFAULT nextval('ContentsServiceIndex_seq'),		/* An index into the tbl_Products table, which for printquotes is a services table.  */
	strStatus		TEXT,
	dtmLastModified	timestamp with time zone,
	servicetype_id	INTEGER NOT NULL,
	PRIMARY KEY (lngServiceIndex)
);

 
