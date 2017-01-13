CREATE TABLE RMA_Products (
	rma_id	INTEGER NOT NULL, FOREIGN KEY rma_id REFERENCES RMA (id),
	product_id	INTEGER NOT NULL, FOREIGN KEY product_id REFERENCES Products (id),
	status_id	INTEGER NOT NULL, FOREIGN KEY status_id REFERENCES RMA_Statuses (id),
	PRIMARY KEY (rma_id,product_id)
);
