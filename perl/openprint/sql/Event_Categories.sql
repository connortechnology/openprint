DROP TABLE IF EXISTS Event_Categories;
CREATE TABLE Event_Categories (
	id SERIAL,
	name	TEXT,
	description	TEXT,
	image_filename	TEXT,
	PRIMARY KEY (id)
);
