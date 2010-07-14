DROP   TABLE IF EXISTS tbl_ProjectType_Defaults;
CREATE TABLE tbl_ProjectType_Defaults (
		lngProjectTypeIndex     INTEGER, FOREIGN KEY (lngProjectTypeIndex) REFERENCES Project_Types (id),
		strFieldName            TEXT,
		strDefaultValue         TEXT
		);

