DROP TABLE IF EXISTS Feeds;
CREATE TABLE Feeds (
	id	SERIAL,
	name	TEXT,
	url		TEXT,
	company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	PRIMARY KEY (id)
);
