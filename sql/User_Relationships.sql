DROP TABLE IF EXISTS User_Relationships;


CREATE TABLE User_Relationship_Types (
	id SERIAL,
	name	TEXT,
	sort	INTEGER,
	PRIMARY KEY (id)
);

CREATE TABLE User_Relationships (
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES User_Relationship_Types (id),
	user_id1	INTEGER NOT NULL, FOREIGN KEY (user_id1) REFERENCES Users(id),
	user_id2	INTEGER NOT NULL, FOREIGN KEY (user_id2) REFERENCES Users(id),
	approved	BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (type_id,user_id1,user_id2)
);
