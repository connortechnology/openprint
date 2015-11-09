
DROP TABLE IF EXISTS tbl_Equipment_Specifications;
DROP	SEQUENCE IF EXISTS EquipmentSpecification_seq;
CREATE	SEQUENCE EquipmentSpecification_seq;

CREATE TABLE tbl_Equipment_Specifications (
	lngIndex	INT4 NOT NULL DEFAULT nextval('EquipmentSpecification_seq'),
	lngEquipmentIndex	INT4 NOT NULL, FOREIGN KEY (lngEquipmentIndex) REFERENCES tbl_Equipment (Id),
	dblMin				NUMERIC(10,4),
	dblMax				NUMERIC(10,4),
	strUnits			TEXT,
	strName				TEXT,
	strValue			TEXT,
	interpolate			BOOLEAN NOT NULL DEFAULT false,
	PRIMARY KEY (lngIndex)
);

CREATE INDEX EquipmentSpecificationName ON tbl_Equipment_Specifications ( lngEquipmentIndex, strName );

