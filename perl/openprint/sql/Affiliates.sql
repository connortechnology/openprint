DROP TABLE IF EXISTS Affiliates;
CREATE TABLE AFFILIATES (
	id	SERIAL,
	name	TEXT,
	url		TEXT,
	image_url	TEXT,
	supplier_id	INTEGER, FOREIGN KEY (supplier_id) REFERENCES Companies (id),
	created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	title	TEXT,
	sort	INTEGER,
	PRIMARY KEY (id)
);
