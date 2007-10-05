DROP TABLE Products;
DROP SEQUENCE Product_id_seq;
CREATE SEQUENCE Product_id_seq;

CREATE TABLE Products (
	id			INTEGER NOT NULL DEFAULT nextval('Product_Id_seq'),
	Category_Id	INTEGER, FOREIGN KEY (Category_id) REFERENCES Product_Categories (id),
	name		TEXT,
	description	TEXT,
	ysnTaxExempt1 char(1) NOT NULL DEFAULT 'N',
	ysnTaxExempt2 char(1) NOT NULL DEFAULT 'N',
	weight	FLOAT,
	PRIMARY KEY (id)
);
 
