
DROP TABLE IF EXISTS Bookmarks;
CREATE TABLE Bookmarks (
	id SERIAL,
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	object_id	INTEGER,
	text		TEXT,
	deleted	BOOLEAN NOT NULL Default false,
	PRIMARY KEY (id)
);

CREATE INDEX bookmarks_idx ON bookmarks ( object_type_id, object_id );
