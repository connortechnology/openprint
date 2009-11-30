
DROP TABLE IF EXISTS PurchaseOrder_Logs;
DROP TABLE IF EXISTS PurchaseOrder_Notifications;
DROP TABLE IF EXISTS PurchaseOrder_ContentTypes;
DROP TABLE IF EXISTS PurchaseOrder_Contents;
DROP TABLE IF EXISTS PurchaseOrders;

CREATE TABLE PurchaseOrders (
	id	SERIAL NOT NULL,
	currency_id	INTEGER NOT NULL, FOREIGN KEY (currency_id) REFERENCES Currencies (id),
	complany_id	INTEGER,
	supplier_id	INTEGER,
	total		float,
	subtotal	float,
	federaltax	float,
	federaltax_rate	float,
	federaltax_charge	boolean,
	statetax	float,
	statetax_rate	float,
	statetax_charge	boolean,
	created_by	INTEGER NOT NULL, FOREIGN KEY (created_by) REFERENCES Users (index),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	authorized_by	INTEGER, FOREIGN KEY (authorized_by) REFERENCES Users (index),
	authorized_on	TIMESTAMP WITH TIME ZONE,
	delivered_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	delivered_on_switch	TEXT,
	deleted		BOOLEAN NOT NULL default false,
	shipping_terms	TEXT,
	shipping_method	TEXT,
	vendor_contact		text,
	vendor_name			text,
	vendor_address1		text,
	vendor_address2		text,
	vendor_city			text,
	vendor_country		text,
	vendor_state		text,
	vendor_postalcode	text,
	vendor_phone		text,
	vendor_fax			text,
	vendor_sms			text,
	vendor_email		text,
	shipto_name			text,
	shipto_address1		text,
	shipto_address2		text,
	shipto_city			text,
	shipto_country		text,
	shipto_state		text,
	shipto_postalcode	text,
	shipto_phone		text,
	shipto_fax			text,
	shipto_sms			text,
	shipto_email		text,
	PRIMARY KEY (id)
);


CREATE TABLE PurchaseOrder_COntents (
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

CREATE TABLE PurchaseOrder_ContentTypes (
	id SERIAL NOT NULL,
	name	TEXT,
	PRIMARY KEY (id)
);

CREATE TABLE PurchaseOrder_Notifications (
	po_id	INTEGER NOT NULL, FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (index),
	PRIMARY KEY (po_id, user_id)
);

CREATE TABLE PurchaseOrder_Logs (
	id		SERIAL NOT NULL,
	po_id	INTEGER NOT NULL, FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (index),
	created_on	timestamp with time zone default NOW(),	
	reason		TEXT,
	PRIMARY KEY (id)
);
