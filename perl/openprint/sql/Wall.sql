DROP TABLE IF EXISTS Wall;

CREATE TABLE Wall (
	id	SERIAL,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users(id),
	author_id	INTEGER NOT NULL, FOREIGN KEY (author_id) REFERENCES Users(id),
	message	TEXT,
	PRIMARY KEY (id)
);
