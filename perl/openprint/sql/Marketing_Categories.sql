DROP TABLE Marketing_Categories;
DROP SEQUENCE Marketing_Category_Id_seq;

CREATE SEQUENCE Marketing_Category_Id_seq;

CREATE TABLE Marketing_Categories (
	id 			INTEGER DEFAULT nextval('Marketing_Category_Id_seq'),
	Name		TEXT, UNIQUE(Name),
	Description	TEXT,
	Greeting	TEXT,
	PRIMARY KEY (Id)
);
