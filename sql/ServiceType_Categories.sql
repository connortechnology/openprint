CREATE TABLE ServiceType_Categories (
	id	SERIAL,
	name	TEXT NOT NULL UNIQUE,
	sorting	INTEGER,
	PRIMARY KEY (id)
);
