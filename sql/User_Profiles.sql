DROP TABLE IF EXISTS User_Profiles;

CREATE TABLE User_Profiles (
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	field_id	INTEGER NOT NULL, FOREIGN KEY (field_id) REFERENCES User_Profile_Fields (id),
	value		TEXT,
	PRIMARY KEY (user_id, field_id)
);
