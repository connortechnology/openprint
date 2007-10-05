DROP	SEQUENCE tbl_Service_Defaults_lngID_seq;
CREATE	SEQUENCE tbl_Service_Defaults_lngID_seq;

DROP   TABLE tbl_Service_Defaults;
CREATE TABLE tbl_Service_Defaults ( 
	lngIndex			INT4 NOT NULL default nextval('tbl_Service_Defaults_lngID_seq'),
	lngServiceTypeIndex		INT4, FOREIGN KEY (lngServiceTypeIndex) REFERENCES tbl_Service_Types (lngIndex),
	strFieldName			TEXT,
	strDefaultValue			TEXT,
	PRIMARY KEY( lngIndex )
);
