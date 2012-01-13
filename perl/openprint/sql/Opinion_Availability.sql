DROP TABLE IF EXISTS Opinion_Availability;
CREATE TABLE Opinion_Availability (
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	object_id		INTEGER,
	opinion_type_id	INTEGER NOT NULL, FOREIGN KEY (opinion_type_id) REFERENCES Opinion_types (id),
	PRIMARY KEY (opinion_type_id, object_type_id, object_id)
);
