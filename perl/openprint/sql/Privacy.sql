
DROP TABLE IF EXISTS Privacy;
CREATE TABLE Privacy (
	id	SERIAL,
	object_id	INTEGER NOT NULL,
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	mode	text,
	user_id	INTEGER[],
	relationship_type_id	INTEGER[],
	usergroup_id	INTEGER[],
	PRIMARY KEY (id)
);

CREATE INDEX Privacy_Object_idx on Privacy (object_type_id, object_id);
