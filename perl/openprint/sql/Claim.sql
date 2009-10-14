
DROP TABLE IF EXISTS Claims;

CREATE TABLE CLAIMS (
	id SERIAL,
	company_id			INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	created_by			INTEGER NOT NULL, FOREIGN KEY (created_by) REFERENCES Users (id),
	created_on			TIMESTAMP WITH TIME ZONE NOT NULL Default NOW(),
	updated_on			TIMESTAMP WITH TIME ZONE NOT NULL Default NOW(),
	filed_on			TIMESTAMP WITH TIME ZONE,
	sent_to_accounts_on	TIMESTAMP WITH TIME ZONE,
	invoiced_on			TIMESTAMP WITH TIME ZONE,
	cancelled_on		TIMESTAMP WITH TIME ZONE,
	invoice_id			TEXT,
	po_id				INTEGER, FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
	docket				INTEGER,
	supplier_id			INTEGER, FOREIGN KEY (supplier_id) REFERENCES Companies (id),
	currency_id			INTEGER, FOREIGN KEY (currency_id) REFERENCES Currencies (id),
	total				float,
	federaltax_rate		float,
	federaltax			float,
	federaltax_charge	boolean,
	statetax_rate		float,
	statetax			float,
	statetax_charge		boolean,
	contact_id			INTEGER, FOREIGN KEY (contact_id) REFERENCES Users (id),
	subtotal			float,
	deleted				boolean default false,
	PRIMARY KEY (id)
);
