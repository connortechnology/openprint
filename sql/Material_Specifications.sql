
DROP TABLE IF EXISTS Material_Specifications;
DROP	SEQUENCE IF EXISTS MaterialSpecification_id_seq;
CREATE	SEQUENCE MaterialSpecification_id_seq;

CREATE TABLE Material_Specifications (
	id	INTEGER NOT NULL DEFAULT nextval('MaterialSpecification_id_seq'),
	material_id	INTEGER NOT NULL, FOREIGN KEY (material_id) REFERENCES Materials (id),
	equipment_id	INTEGER, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (id),
	min				NUMERIC(10,4),
	max				NUMERIC(10,4),
	units			TEXT,
	name			TEXT,
	value			TEXT,
  interpolate boolean not null default false,
	PRIMARY KEY (id)
);

CREATE INDEX MaterialSpecificationName ON Material_Specifications ( material_id, name );

