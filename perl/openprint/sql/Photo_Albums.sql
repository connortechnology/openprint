
CREATE TABLE Photo_Albums (
	id	SERIAL,
	name	text,
	description	text,
	user_id	INTEGER, FOREIGN KEY (user_id) REFERENCES Users (id),
	thumbnail_id	INTEGER, FOREIGN KEY (thumbnail_id) REFERENCES Assets (id),
	privacy_mode_id	INTEGER,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	deleted		BOOLEAN NOT NULL default false,
	PRIMARY KEY (id)
);
 ALTER TABLE Article_Categories ADD FOREIGN KEY (album_id) REFERENCES Photo_Albums (id);
