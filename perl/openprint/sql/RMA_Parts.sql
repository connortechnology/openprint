CREATE TABLE RMA_Parts (
	id SERIAL,
	product_id INTEGER NOT NULL, FOREIGN KEY (product_id) REFERENCES Products (id),
	rma_id		INTEGER NOT NULL, FOREIGN KEY (rma_id) REFERENCES RMA (id),
	quantity	INTEGER,
	serialnumber	TEXT,
	PRIMARY KEY (id)
);
