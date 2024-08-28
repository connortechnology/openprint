
DROP TABLE IF EXISTS tbl_Equipment_Specifications;
DROP	SEQUENCE IF EXISTS EquipmentSpecification_seq;
CREATE	SEQUENCE EquipmentSpecification_seq;

CREATE TABLE tbl_Equipment_Specifications (
	lngIndex	INT4 NOT NULL DEFAULT nextval('EquipmentSpecification_seq'),
	lngEquipmentIndex	INT4 NOT NULL, FOREIGN KEY (lngEquipmentIndex) REFERENCES tbl_Equipment (Id),
	dblMin				double precision,
	dblMax				double precision,
  range_units   TEXT,
	strName				TEXT,
	strValue			TEXT,
	strUnits			TEXT,
	interpolate			BOOLEAN NOT NULL DEFAULT false,
  sorting       INTEGER,
	PRIMARY KEY (lngIndex)
);

CREATE INDEX EquipmentSpecificationName ON tbl_Equipment_Specifications ( lngEquipmentIndex, strName );

