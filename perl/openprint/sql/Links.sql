DROP TABLE IF EXISTS Links;
CREATE TABLE Links (
	name	TEXT,
	href	TEXT,
	count	INTEGER,
	sorting	INTEGER,
	id SERIAL,
	PRIMARY KEY (id)
);
