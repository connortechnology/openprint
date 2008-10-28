
DROP TABLE IF EXISTS  PurchaseOrders;
CREATE TABLE PurchaseOrders (
	id	SERIAL NOT NULL,
	currency_id	INTEGER NOT NULL, FOREIGN KEY (currency_id) REFERENCES Currencies (id),
	supplier_id	INTEGER,
	total		float,
	subtotal	float,
	tax			float,
	created_by	INTEGER NOT NULL, FOREIGN KEY (created_by) REFERENCES Users (index),
	authorized_by	INTEGER, FOREIGN KEY (authorized_by) REFERENCES Users (index),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	authorized_on	TIMESTAMP WITH TIME ZONE,
	delivered_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	deleted		BOOLEAN NOT NULL default false,
	shipping_terms	TEXT,
	shipping_method	TEXT,
	PRIMARY KEY (id)
);

DROP TABLE IF EXISTS PurchaseOrder_Contents;

CREATE TABLE PurchaseOrder_COntents (
	id SERIAL NOT NULL,
	po_id	INTEGER NOT NULL, FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
	qty		float,
	price	float,
	total	float,
	item	text,
	docket	text,
	description	text,
	PRIMARY KEY (id)
);
