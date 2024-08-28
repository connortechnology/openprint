
DROP   TABLE IF EXISTS tbl_Service_Defaults;
CREATE TABLE tbl_Service_Defaults ( 
	lngIndex			SERIAL,
  projecttype_id  INTEGER, FOREIGN KEY (projecttype_id) REFERENCES project_types (id),
	lngServiceTypeIndex		INTEGER, FOREIGN KEY (lngServiceTypeIndex) REFERENCES Service_Types (id),
	strFieldName			TEXT,
	strDefaultValue			TEXT,
	PRIMARY KEY( lngIndex )
);
