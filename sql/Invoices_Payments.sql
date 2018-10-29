DROP TABLE IF EXISTS Invoices_Payments;
CREATE TABLE Invoices_Payments (
	id	SERIAL,
	payment_id	INTEGER NOT NULL, FOREIGN KEY (payment_id) REFERENCES Payments (id),
	invoice_id	INTEGER NOT NULL, FOREIGN KEY (invoice_id) REFERENCES Invoices (id),
	amount		float,
	PRIMARY KEY (id)
);

CREATE INDEX invoices_payments_idx on invoices_payments (invoice_id,payment_id);
