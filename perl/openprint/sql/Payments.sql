DROP TABLE Payments;

CREATE TABLE Payments ( 
	id					SERIAL NOT NULL,
	order_id			INTEGER, FOREIGN KEY (order_id) REFERENCES Orders (index),
	owner_id			INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (id),
	payor_id			INTEGER NOT NULL, FOREIGN KEY (payor_id) REFERENCES Companies (id),
	amount				FLOAT,
	created_on			TIMESTAMP WITH TIME ZONE,
	method				TEXT,
	currency_id			INTEGER NOT NULL, FOREIGN KEY (currency_id) REFERENCES Currency (index),
	transaction_id		TEXT,
	description			TEXT,
	PRIMARY KEY( id )
);
