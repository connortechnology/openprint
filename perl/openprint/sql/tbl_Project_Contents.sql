DROP	SEQUENCE ContentsServiceIndex_seq;
CREATE	SEQUENCE ContentsServiceIndex_seq;

DROP TABLE tbl_Project_Contents;

CREATE TABLE tbl_Project_Contents (
	lngProjectIndex	INT4 NOT NULL,		/* Index into the Projects table, which identifies the project that the contents belong to */
FOREIGN KEY (lngProjectIndex) REFERENCES Projects (Index),
	lngServiceIndex INT4 NOT NULL DEFAULT nextval('ContentsServiceIndex_seq'),		/* An index into the tbl_Products table, which for printquotes is a services table.  */
	strStatus		TEXT,
	dtmLastModified	timestamp with time zone,
	PRIMARY KEY (lngServiceIndex)
);

 
