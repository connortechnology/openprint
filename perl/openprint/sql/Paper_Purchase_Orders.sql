
DROP TABLE Paper_Purchase_Order_Contents;
DROP TABLE Paper_Purchase_Orders;
DROP	SEQUENCE  PaperPurchaseOrder_Id_seq;


CREATE	SEQUENCE  PaperPurchaseOrder_Id_seq;

CREATE TABLE Paper_Purchase_Orders (
	id			INTEGER NOT NULL default nextval('PaperPurchaseOrder_Id_seq'),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (Index),
	Created_on			TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	Received		DATE,
	ExpectedArrival	DATE,
	Sent			DATE,
	Status			TEXT,
	Total			NUMERIC(10,2) NOT NULL default '0.00',
	GST				NUMERIC(10,2) NOT NULL default '0.00',
	SupplierTo				TEXT,
	SupplierAttn			TEXT,
	SupplierFrom			TEXT,
	SupplierFaxNo			TEXT,
	PONum					INTEGER,
	Currency_Id			INTEGER, FOREIGN KEY (Currency_Id) REFERENCES Currencies (id),
	WarehouseLocation		TEXT,
	PRIMARY KEY (Id)
);

CREATE TABLE Paper_Purchase_Order_Contents (
	PaperPurchaseOrder_Id	INTEGER NOT NULL, FOREIGN KEY (PaperPurchaseOrder_Id) REFERENCES Paper_Purchase_Orders (Id),
	Paper_Id				INTEGER NOT NULL, FOREIGN KEY (Paper_Id) REFERENCES Papers (Id),
	Quantity				INTEGER NOT NULL,
	Description				TEXT NOT NULL,
	Price					NUMERIC(10,2) NOT NULL default '0.00'
);

