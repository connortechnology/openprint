DROP TABLE IF EXISTS Expenditures;

CREATE TABLE Expenditures (
	id	SERIAL,
	amount	float,
	owner_id	INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (id),
	payor_id	INTEGER NOT NULL, FOREIGN KEY (payor_id) REFERENCES Companies (id),
	description	TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	occurred_on	TIMESTAMP WITH TIME ZONE NOT NULL,
	currency_id	INTEGER NOT NULL, FOREIGN KEY (currency_id) REFERENCES CUrrencies (id),
	federaltax_rate	float,
	PRIMARY KEY (id)
);
