
CREATE TABLE Authorizations (
	id	SERIAL,
	object_id	INTEGER NOT NULL,
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	mode	text,
	user_id	INTEGER[],
	usertype_id	INTEGER[],
	usergroup_id	INTEGER[],
	setting	TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX Authorizations_Object_idx on Authorizations (object_type_id, object_id);
