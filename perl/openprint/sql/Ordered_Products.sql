DROP TABLE IF EXISTS Ordered_Products;

CREATE TABLE Ordered_Products (
	id			SERIAL,
	order_id	INTEGER	NOT NULL, FOREIGN KEY (order_id) REFERENCES Orders (Index),
	product_id	INTEGER	NOT NULL, FOREIGN KEY (product_id) REFERENCES Products (id),
	quantity	INTEGER,
	price		NUMERIC(10,2),
	requested_for	date,
	due_on			date,
	shipping_type	text,
	gst				NUMERIC(10,2),
	hst				NUMERIC(10,2),
	pst				NUMERIC(10,2),
	PRIMARY KEY (id)
);
CREATE INDEX OrderedProducts_idx on Ordered_Products (order_id, product_id);
