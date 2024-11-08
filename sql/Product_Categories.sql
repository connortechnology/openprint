DROP TABLE IF EXISTS Product_Categories;

CREATE TABLE Product_Categories (
	id		SERIAL NOT NULL,
	name			TEXT,
	projecttype_id	INTEGER, FOREIGN KEY (projecttype_id) REFERENCES Project_Types (id),
	description		TEXT,
	deleted			BOOLEAN NOT NULL default false,
  /*
	parent_ids		INTEGER[],
*/
	parent_id		INTEGER,
	sorting			INTEGER,
	album_id		INTEGER, FOREIGN KEY (album_id) REFERENCES Photo_Albums (id),
	PRIMARY KEY (id)
);
