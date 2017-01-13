DROP TABLE IF EXISTS Product_Prices;
CREATE TABLE Product_Prices (
	id				SERIAL,
	product_id		INTEGER NOT NULL, FOREIGN KEY (product_id) REFERENCES Products (id),
	pricelist_id	INTEGER NOT NULL, FOREIGN KEY (pricelist_id) REFERENCES Pricelists (id),
	min				float,
	max				float,
	units			TEXT,
	cost			float,
	markup			float,
	price			float,
	discountable	BOOLEAN NOT NULL default true,
	owner_id		INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES companies (id),
	PRIMARY KEY (id)
);
CREATE Index Product_Price_Product_idx ON Product_Prices (product_id, pricelist_id);
