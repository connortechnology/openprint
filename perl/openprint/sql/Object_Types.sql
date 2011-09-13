DROP TABLE IF EXISTS Object_Types;

CREATE TABLE Object_Types (
	id	SERIAL,
	name	TEXT UNIQUE,
	human	TEXT,
	PRIMARY KEY (id)
);
