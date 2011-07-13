
DROP TABLE IF EXISTS Bookmarks;
CREATE TABLE Bookmarks (
	id SERIAL,
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	object_type	TEXT,
	object_id	INTEGER,
	text		TEXT,
	deleted	BOOLEAN NOT NULL Default false,
	PRIMARY KEY (id)
);

CREATE INDEX bookmarks_idx ON comments ( object_type, object_id );
