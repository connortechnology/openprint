DROP TABLE IF EXISTS Wall;

CREATE TABLE Wall (
	id	SERIAL,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	source_id	INTEGER NOT NULL,
	source_type	TEXT,
	description	TEXT,
	PRIMARY KEY (id)
);
