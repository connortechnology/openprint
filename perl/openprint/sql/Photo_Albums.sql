DROP TABLE IF EXISTS Photos_in_Albums;
DROP TABLE IF EXISTS Photo_Albums;

CREATE TABLE Photo_Albums (
	id	SERIAL,
	name	text,
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	thumbnail_id	INTEGER, FOREIGN KEY (thumbnail_id) REFERENCES Assets (id),
	privacy_mode_id	INTEGER,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	deleted		BOOLEAN NOT NULL default false,
	PRIMARY KEY (id)
);

CREATE TABLE Photos_in_Albums (
	album_id	INTEGER NOT NULL, FOREIGN KEY (album_id) REFERENCES Photo_albums (id),
	asset_id	INTEGER NOT NULL, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	PRIMARY KEY (album_id,asset_id)
);
