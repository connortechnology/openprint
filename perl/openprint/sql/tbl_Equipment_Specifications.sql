
DROP TABLE tbl_Equipment_Specifications;
DROP	SEQUENCE EquipmentSpecification_seq;
CREATE	SEQUENCE EquipmentSpecification_seq;

CREATE TABLE tbl_Equipment_Specifications (
	lngIndex	INT4 NOT NULL DEFAULT nextval('EquipmentSpecification_seq'),
	lngEquipmentIndex	INT4 NOT NULL, FOREIGN KEY (lngEquipmentIndex) REFERENCES tbl_Equipment (lngIndex),
	dblMin				NUMERIC(10,4),
	dblMax				NUMERIC(10,4),
	strUnits			TEXT,
	strName				TEXT,
	strValue			TEXT,
	PRIMARY KEY (lngIndex)
);

CREATE INDEX EquipmentSpecificationName ON tbl_Equipment_Specifications ( lngEquipmentIndex, strName );

