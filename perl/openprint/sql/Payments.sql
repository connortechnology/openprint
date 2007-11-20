DROP TABLE Payments;
DROP	SEQUENCE Payments_id_seq;

CREATE	SEQUENCE Payments_Id_seq;
CREATE TABLE Payments ( 
	id			INTEGER NOT NULL default nextval('Payments_Id_seq'),	
	order_id			INTEGER, FOREIGN KEY (Order_Id) REFERENCES Orders (index),
	Company_id		INTEGER NOT NULL, FOREIGN KEY (Company_id) REFERENCES Company (index),
	strSessionID		TEXT,
	curAmount			NUMERIC(10,2),
	dtmDate				TIMESTAMP,
	strMethod			TEXT,
	Currency_id			INTEGER NOT NULL, FOREIGN KEY (currency_id) REFERENCES Currency (index),
	strTransactionID	TEXT,
	strDescription		TEXT,
	PRIMARY KEY( Id )
);
