
CREATE TABLE Photos_in_Albums (
	id			SERIAL,
	album_id	INTEGER NOT NULL, FOREIGN KEY (album_id) REFERENCES Photo_albums (id),
	asset_id	INTEGER NOT NULL, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	sort		INTEGER,
	PRIMARY KEY (id)
);
CREATE INDEX Photos_in_Albums_idx ON Photos_in_Albums (album_id, asset_id);
