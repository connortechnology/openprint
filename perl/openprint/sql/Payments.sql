DROP TABLE Payments;

CREATE TABLE Payments ( 
	id					SERIAL NOT NULL,
	order_id			INTEGER, FOREIGN KEY (order_id) REFERENCES Orders (index),
	company_id			INTEGER NOT NULL, FOREIGN KEY (Company_id) REFERENCES Company (index),
	amount				FLOAT,
	created_on			TIMESTAMP WITH TIME ZONE,
	method				TEXT,
	currency_id			INTEGER NOT NULL, FOREIGN KEY (currency_id) REFERENCES Currency (index),
	transaction_id		TEXT,
	description			TEXT,
	PRIMARY KEY( id )
);
