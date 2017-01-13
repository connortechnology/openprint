DROP TABLE IF EXISTS Feeds;
CREATE TABLE Feeds (
	id	SERIAL,
	name	TEXT,
	type	TEXT,
	url		TEXT,
	company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	category_id	INTEGER, FOREIGN KEY (category_id) REFERENCES Article_Categories (id),
	published	BOOLEAN NOT NULL DEFAULT false,
	PRIMARY KEY (id)
);
