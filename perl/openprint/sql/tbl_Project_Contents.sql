DROP SEQUENCE IF EXISTS ContentsServiceIndex_seq;
CREATE SEQUENCE ContentsServiceIndex_seq;
DROP TABLE IF EXISTS tbl_Project_Contents;

CREATE TABLE tbl_Project_Contents (
	lngProjectIndex	INTEGER NOT NULL,		/* Index into the Projects table, which identifies the project that the contents belong to */
FOREIGN KEY (lngProjectIndex) REFERENCES Projects (Id),
	lngServiceIndex INTEGER NOT NULL DEFAULT nextval('ContentsServiceIndex_seq'),		/* An index into the tbl_Products table, which for printquotes is a services table.  */
	strStatus		TEXT,
	dtmLastModified	timestamp with time zone,
	servicetype_id	INTEGER,
	operator_id		INTEGER, FOREIGN KEY (operator_id) REFERENCES Users (id),
	PRIMARY KEY (lngServiceIndex)
);

 
ALTER TABLE ONLY tbl_project_contents
    ADD CONSTRAINT tbl_project_contents_servicetype_id_fkey FOREIGN KEY (servicetype_id) REFERENCES service_types(id);

create index project_contents_idx on tbl_project_contents (lngprojectindex,lngserviceindex);
