DROP TABLE IF EXISTS Invoiced_Products;

CREATE TABLE Invoiced_Products (
	id	SERIAL NOT NULL,
	price		float,
	quantity	integer,
	invoice_id	INTEGER, FOREIGN KEY (invoice_id) REFERENCES Invoices (id),
	product_id	INTEGER, FOREIGN KEY (product_id) REFERENCES Products (id),
	description	TEXT,
	PRIMARY KEY (id)
);
