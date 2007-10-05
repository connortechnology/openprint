DROP TABLE Product_Categories;
DROP SEQUENCE Product_Category_Id_seq;
CREATE SEQUENCE Product_Category_Id_seq;

CREATE TABLE Product_Categories (
	id		INTEGER	NOT NULL DEFAULT nextval('Product_Category_Id_seq'),
	name			TEXT,
	projecttype_id	INTEGER, FOREIGN KEY (projecttype_id) REFERENCES Project_Types (lngIndex),
	description		TEXT,
	PRIMARY KEY (id)
);
