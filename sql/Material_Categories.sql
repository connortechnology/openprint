DROP	TABLE IF EXISTS Material_Categories;

CREATE TABLE Material_Categories (
	id		SERIAL,
	name 	TEXT,
  price_unit integer, FOREIGN KEY (price_unit) REFERENCES units (id),
  ranged_unit integer, FOREIGN KEY (ranged_unit) REFERENCES units (id),
	PRIMARY KEY (id)
);
