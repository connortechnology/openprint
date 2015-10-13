CREATE TABLE PurchaseOrder_Items_to_Inventory_Items (
	purchaseorder_item_id	INTEGER NOT NULL,
	inventory_item_id	INTEGER NOT NULL,
	inventory_object_type_id	INTEGER NOT NULL, FOREIGN KEY (inventory_object_type_id) REFERENCES object_types (id),
	PRIMARY KEY (purchaseorder_item_id,inventory_item_id,inventory_object_type_id)
);
