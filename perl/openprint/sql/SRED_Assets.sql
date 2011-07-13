DROP TABLE IF EXISTS SRED_Assets;

CREATE TABLE SRED_Assets (
	asset_id	INTEGER NOT NULL, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	content_id	INTEGER NOT NULL, FOREIGN KEY (content_id) REFERENCES SRED_Contents (id),
	PRIMARY KEY (content_id,asset_id)
);
