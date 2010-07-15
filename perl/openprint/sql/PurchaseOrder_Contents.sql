
DROP TABLE IF EXISTS PurchaseOrder_Contents;

CREATE TABLE PurchaseOrder_Contents (
	id SERIAL NOT NULL,
	po_id	INTEGER NOT NULL, FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
	type_id	INTEGER, FOREIGN KEY (type_id) REFERENCES PurchaseOrder_ContentTypes (id),
	qty		float,
	price	float,
	total	float,
	item	text,
	docket	text,
	description	text,
	PRIMARY KEY (id)
);

