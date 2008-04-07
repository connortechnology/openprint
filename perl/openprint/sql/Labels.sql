DROP TABLE IF EXISTS Label_Data;
DROP TABLE IF EXISTS Labels;
DROP TABLE IF EXISTS LabelTypes;

CREATE TABLE LabelTypes (
	id	SERIAL NOT NULL,
	name	TEXT,
	PRIMARY KEY (id)
);

CREATE TABLE Labels (
	id	SERIAL NOT NULL,
	version	INTEGER,
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES LabelTypes (id),
	docket	INTEGER NOT NULL,
	reference	text,
	content	text,
	data	text,
	created_on	timestamp with time zone NOT NULL default NOW(),
	PRIMARY KEY (id)
);

CREATE TABLE Label_Data (
	label_id	INTEGER NOT NULL, FOREIGN KEY (label_id) REFERENCES Labels (id),
	name		text	NOT NULL,
	value		text,
	PRIMARY KEY (label_id,name)
);
