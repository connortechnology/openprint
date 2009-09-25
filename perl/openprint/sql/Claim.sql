
DROP TABLE IF EXISTS Claims;

CREATE TABLE CLAIMS (
	id SERIAL,
	created_by			INTEGER NOT NULL, FOREIGN KEY (created_by) REFERENCES Users (Index),
	created_on			TIMESTAMP WITH TIME ZONE NOT NULL Default NOW(),
	updated_on			TIMESTAMP WITH TIME ZONE NOT NULL Default NOW(),
	filed_on			TIMESTAMP WITH TIME ZONE,
	sent_to_accounts_on	TIMESTAMP WITH TIME ZONE,
	invoiced_on			TIMESTAMP WITH TIME ZONE,
	cancelled_on		TIMESTAMP WITH TIME ZONE,
	invoice_id			TEXT,
	po_id				INTEGER, FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
	docket				INTEGER,
	supplier_id			INTEGER, FOREIGN KEY (supplier_id) REFERENCES Company (index),
	currency_id			INTEGER, FOREIGN KEY (currency_id) REFERENCES Currencies (id),
	total				float,
	federaltax_rate		float,
	federaltax			float,
	statetax_rate		float,
	statetax			float,
	PRIMARY KEY (id)
);
