DROP TABLE IF EXISTS Product_Categories;

CREATE TABLE Product_Categories (
	id		SERIAL NOT NULL,
	name			TEXT,
	projecttype_id	INTEGER, FOREIGN KEY (projecttype_id) REFERENCES Project_Types (id),
	description		TEXT,
	deleted			BOOLEAN NOT NULL default false,
	parent_ids		INTEGER[],
	sorting			INTEGER,
	PRIMARY KEY (id)
);
