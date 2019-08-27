CREATE TABLE Opinions (
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	object_id	INTEGER,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	value		INTEGER,
	opinion_type_id	INTEGER NOT NULL, FOREIGN KEY (opinion_type_id) REFERENCES Opinion_Types (id),
	PRIMARY KEY ( object_id, object_type_id, user_id, opinion_type_id )
);
