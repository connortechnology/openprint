
DROP   TABLE IF EXISTS tbl_Service_Defaults;
CREATE TABLE tbl_Service_Defaults ( 
	lngIndex			SERIAL,
	lngServiceTypeIndex		INTEGER, FOREIGN KEY (lngServiceTypeIndex) REFERENCES Service_Types (id),
	strFieldName			TEXT,
	strDefaultValue			TEXT,
	PRIMARY KEY( lngIndex )
);
