CREATE TABLE PurchaseOrder_Contents (
	id SERIAL NOT NULL,
	po_id	INTEGER NOT NULL, FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
	type_id	INTEGER, FOREIGN KEY (type_id) REFERENCES PurchaseOrder_ContentTypes (id),
	qty		float,
	price	float,
	total	float,
	item_id	INTEGER, FOREIGN KEY (item_id) REFERENCES PurchaseOrder_Items (id),
	docket	text,
	description	text,
	object_type_id	INTEGER, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	object_id	INTEGER,
	PRIMARY KEY (id)
);

