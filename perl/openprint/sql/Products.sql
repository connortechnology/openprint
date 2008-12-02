DROP TABLE IF EXISTS Products;

CREATE TABLE Products (
	id			SERIAL NOT NULL,
	category_id	INTEGER, FOREIGN KEY (Category_id) REFERENCES Product_Categories (id),
	name		TEXT,
	description	TEXT,
	ysnTaxExempt1 char(1) NOT NULL DEFAULT 'N',
	ysnTaxExempt2 char(1) NOT NULL DEFAULT 'N',
	weight	FLOAT,
	PRIMARY KEY (id)
);
 
