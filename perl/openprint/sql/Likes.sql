DROP TABLE IF EXISTS Likes;
CREATE TABLE Likes (
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	object_type	TEXT,
	object_id	INTEGER,
	PRIMARY KEY (user_id, object_id, object_type )
);
