DROP	TABLE IF EXISTS Material_Categories;

CREATE TABLE Material_Categories (
	id		SERIAL,
	name 	TEXT,
  price_unit integer,
  ranged_unit integer,
	PRIMARY KEY (id)
);
