
DROP TABLE IF EXISTS User_PurchaseOrder_Limits;
CREATE TABLE User_PurchaseOrder_Limits (
	user_id	INTEGER	NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES purchaseorder_contenttypes(id),
	po_limit	INTEGER,
	total_limit	INTEGER,
	PRIMARY KEY (user_id,type_id)
);
