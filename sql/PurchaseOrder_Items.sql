DROP TABLE IF EXISTS PurchaseOrder_Items;

CREATE TABLE PurchaseOrder_Items (
	id SERIAL,
	company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	vendor_id	INTEGER NOT NULL, FOREIGN KEY (vendor_id) REFERENCES Companies (id),
	name		TEXT NOT NULL,
	price		FLOAT,
	type_id		INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES PurchaseOrder_ContentTypes (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	PRIMARY KEY (id)
);
CREATE INDEX PurchaseOrder_Items_idx on PurchaseOrder_Items (company_id,vendor_id,type_id, name);
