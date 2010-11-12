DROP TABLE Payments;

CREATE TABLE Payments ( 
	id					SERIAL NOT NULL,
	order_id			INTEGER, FOREIGN KEY (order_id) REFERENCES Orders (id),
	owner_id			INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (id),
	payor_id			INTEGER NOT NULL, FOREIGN KEY (payor_id) REFERENCES Companies (id),
	amount				FLOAT,
	created_on			TIMESTAMP WITH TIME ZONE,
	updated_on			TIMESTAMP WITH TIME ZONE,
	method				TEXT,
	currency_id			INTEGER NOT NULL, FOREIGN KEY (currency_id) REFERENCES Currencies (id),
	transaction_id		TEXT,
	description			TEXT,
	completed			BOOLEAN not null default false,
	deleted				BOOLEAN not NULL default false,
	type_id				INTEGER, FOREIGN KEY (type_id) REFERENCES PaymentTypes (id),
	PRIMARY KEY( id )
);
