
DROP TABLE IF EXISTS PRivacy;
CREATE TABLE Privacy (
	id	SERIAL,
	object_id	INTEGER NOT NULL,
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	relationship_id	INTEGER	NOT NULL, FOREIGN KEY (relationship_id) REFERENCES User_Relationship_Types (id),
	value	text,
	PRIMARY KEY (id)
);

CREATE INDEX Privacy_Object_idx on Privacy (object_type_id, object_id);
