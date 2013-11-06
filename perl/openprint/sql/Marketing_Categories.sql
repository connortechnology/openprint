DROP TABLE IF EXISTS Marketing_Categories;

CREATE TABLE Marketing_Categories (
	id 			SERIAL NOT NULL,
	Name		TEXT, UNIQUE(Name),
	Description	TEXT,
	Greeting	TEXT,
	PRIMARY KEY (Id)
);
