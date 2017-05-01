DROP TABLE IF EXISTS Product_Categories;

CREATE TABLE Product_Categories (
	id		SERIAL NOT NULL,
	name			TEXT,
	projecttype_id	INTEGER, FOREIGN KEY (projecttype_id) REFERENCES Project_Types (id),
	description		TEXT,
	deleted			BOOLEAN default false,
	parent_ids		INTEGER[],
	PRIMARY KEY (id)
);
