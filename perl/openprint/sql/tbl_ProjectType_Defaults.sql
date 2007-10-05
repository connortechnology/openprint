DROP   TABLE tbl_ProjectType_Defaults;
CREATE TABLE tbl_ProjectType_Defaults (
		lngProjectTypeIndex     INT4, FOREIGN KEY (lngProjectTypeIndex) REFERENCES Project_Types (lngIndex),
		strFieldName            TEXT,
		strDefaultValue         TEXT
		);

