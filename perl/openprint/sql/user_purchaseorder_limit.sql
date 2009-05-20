
DROP TABLE IF EXISTS user_purchaseorder_limit;

CREATE TABLE user_purchaseorder_limit (
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES users (index),
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES PurchaseOrder_COntentTypes (id),
	po_limit	INTEGER,
	total_limit	INTEGER,
	PRIMARY KEY (user_id,type_id)
);
