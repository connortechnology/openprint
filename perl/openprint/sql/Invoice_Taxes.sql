CREATE TABLE Invoice_Taxes (
	id	SERIAL,
	invoice_id	INTEGER NOT NULL, FOREIGN KEY (invoice_id) REFERENCES Invoices (id),
	tax_id		INTEGER NOT NULL, FOREIGN KEY (tax_id) REFERENCES Taxes (id),
	rate		float,
	amount		float,
	PRIMARY KEY (id)
);
