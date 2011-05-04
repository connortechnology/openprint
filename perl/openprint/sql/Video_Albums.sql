DROP TABLE IF EXISTS Videos_in_Albums;
DROP TABLE IF EXISTS Video_Albums;

CREATE TABLE Video_Albums (
	id	SERIAL,
	name	text,
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	thumbnail_id	INTEGER, FOREIGN KEY (thumbnail_id) REFERENCES Assets (id),
	privacy_mode_id	INTEGER,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	deleted		BOOLEAN NOT NULL default false,
	PRIMARY KEY (id)
);

CREATE TABLE Videos_in_Albums (
	album_id	INTEGER NOT NULL, FOREIGN KEY (album_id) REFERENCES Video_albums (id),
	asset_id	INTEGER NOT NULL, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	PRIMARY KEY (album_id,asset_id)
);
