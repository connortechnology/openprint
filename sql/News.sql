DROP TABLE IF EXISTS News;

CREATE TABLE News (
	id	SERIAL,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	owner_id	INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Users(id),
	creator_id	INTEGER NOT NULL, FOREIGN KEY (creator_id) REFERENCES Users(id),
	source_id	INTEGER NOT NULL,
	source_type	TEXT,
	description	TEXT,
	PRIMARY KEY (id)
);
