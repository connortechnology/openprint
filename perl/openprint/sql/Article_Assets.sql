CREATE TABLE Article_Assets (
	asset_id	INTEGER NOT NULL, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	article_id	INTEGER NOT NULL, FOREIGN KEY (article_id) REFERENCES Articles (id),
	PRIMARY KEY (article_id,asset_id)
);
