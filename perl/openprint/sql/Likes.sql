DROP TABLE IF EXISTS Likes;
CREATE TABLE Likes (
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	object_id	INTEGER,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	value		INTEGER,
	PRIMARY KEY (user_id, object_id, object_type_id )
);
