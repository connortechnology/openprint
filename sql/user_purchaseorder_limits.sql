
DROP TABLE IF EXISTS user_purchaseorder_limits;

CREATE TABLE user_purchaseorder_limits (
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES users (id),
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES PurchaseOrder_COntentTypes (id),
	po_limit	INTEGER,
	total_limit	INTEGER,
	PRIMARY KEY (user_id,type_id)
);
