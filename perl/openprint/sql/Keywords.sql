DROP TABLE IF EXISTS Keywords;
CREATE TABLE Keywords (
	id	SERIAL,
	word	TEXT,
	PRIMARY KEY (id)
);

DROP TABLE IF EXISTS Object_Keywords;
CREATE TABLE Object_Keywords (
	keyword_id	INTEGER NOT NULL, FOREIGN KEY (keyword_id) REFERENCES Keywords (id),
	object_id	INTEGER NOT NULL, 
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types(id),
	PRIMARY KEY (object_id, object_type_id, keyword_id)
);
