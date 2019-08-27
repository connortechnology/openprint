CREATE TABLE Tests (
	id	SERIAL,
	name	TEXT,
	description	TEXT,
	mandatory	BOOLEAN NOT NULL DEFAULT False,
	PRIMARY KEY (id)
);

