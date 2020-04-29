CREATE TABLE Object_Specifications (
	id			SERIAL,
	object_id	INTEGER NOT NULL,
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	name		TEXT,
	value		TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX Object_specifications_idx on Object_Specifications (object_type_id,object_id);
