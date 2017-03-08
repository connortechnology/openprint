DROP TABLE IF EXISTS Product_Categories;

CREATE TABLE Product_Categories (
	id		SERIAL NOT NULL,
	name			TEXT,
	projecttype_id	INTEGER, FOREIGN KEY (projecttype_id) REFERENCES Project_Types (id),
	description		TEXT,
	deleted			BOOLEAN default false,
	parent_id		INTEGER, FOREIGN KEY (parent_id) REFERENCES Product_Categories (id),
	PRIMARY KEY (id)
);
