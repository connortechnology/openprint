DROP SEQUENCE Product_Prices_id_seq;
CREATE SEQUENCE Product_Prices_id_seq;
DROP TABLE Product_Prices;
CREATE TABLE Product_Prices (
	id				INTEGER NOT NULL DEFAULT nextval('Product_Prices_id_seq'),
	product_id		INTEGER NOT NULL, FOREIGN KEY (product_id) REFERENCES Products (id),
	pricelist_id	INTEGER NOT NULL, FOREIGN KEY (pricelist_id) REFERENCES Pricelists (index),
	min				float,
	max				float,
	units			TEXT,
	cost			float,
	markup			float,
	price			float,
	PRIMARY KEY (id)
);
CREATE Index Product_Price_Product_idx ON Product_Prices (product_id, pricelist_id);
