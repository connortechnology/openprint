DROP TABLE IF EXISTS Product_Specifications;
CREATE TABLE Product_Specifications (
	id			SERIAL,
	product_id	INTEGER NOT NULL, FOREIGN KEY (product_id) REFERENCES Products (id),
	name		TEXT,
	value		TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX Product_specifications_idx on Product_Specifications (product_id,name);
