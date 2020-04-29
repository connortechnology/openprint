CREATE TABLE TrackBacks (
	id	SERIAL,
	blog_name	TEXT,
	excerpt		TEXT,
	title		TEXT,
	url			TEXT,
	article_id	INTEGER,  FOREIGN KEY (article_id) REFERENCES Articles (id),
	PRIMARY KEY (id)
);
