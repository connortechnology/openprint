DROP TABLE tbl_Service_Specifications;

CREATE TABLE tbl_Service_Specifications (
	lngProjectIndex	INT4 NOT NULL, FOREIGN KEY (lngProjectIndex) REFERENCES Projects (Index),
	lngServiceIndex	INT4 NOT NULL, FOREIGN KEY (lngServiceIndex) REFERENCES tbl_Project_Contents (lngServiceIndex),
	strName			TEXT,
	strValue		TEXT
);

CREATE INDEX Service_Specs_Service_Index ON tbl_Service_Specifications (lngServiceIndex);
/* CREATE INDEX Service_Specs_Project_Index ON tbl_Service_Specifications (lngProjectIndex); */
/* CREATE INDEX Service_Specs_Index ON tbl_Service_Specifications (lngProjectIndex,lngServiceIndex); */
 CREATE INDEX Service_Specs_IndexNameValue ON tbl_Service_Specifications (lngProjectIndex, strName, strValue);

