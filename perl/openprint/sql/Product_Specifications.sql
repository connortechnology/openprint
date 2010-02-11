DROP TABLE IF EXISTS Product_Specifications;
CREATE TABLE Product_Specifications (
	product_id	INTEGER NOT NULL, FOREIGN KEY (product_id) REFERENCES Products (id),
	name		TEXT,
	value		TEXT
);

CREATE INDEX Product_Specifications_idx ON Product_Specifications (product_id);
