DROP TABLE IF EXISTS Product_Categories;

CREATE TABLE Product_Categories (
	id		SERIAL NOT NULL,
	name			TEXT,
	projecttype_id	INTEGER, FOREIGN KEY (projecttype_id) REFERENCES Project_Types (Id),
	description		TEXT,
	deleted			BOOLEAN default false,
	PRIMARY KEY (id)
);
