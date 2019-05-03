CREATE TABLE RFIDScanners (
	id	SERIAL NOT NULL,
	name	TEXT,
	ipaddr	TEXT,
	type	TEXT,
	location_id	INTEGER, FOREIGN KEY (location_id) REFERENCES Locations (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	PRIMARY KEY (id)
);
CREATE TABLE RFIDScannerHistory (
	id	SERIAL NOT NULL,
	scanner_id	INTEGER, FOREIGN KEY (scanner_id) REFERENCES RFIDScanners (id),
	location_id	INTEGER NOT NULL, FOREIGN KEY (location_id) REFERENCES Locations (id),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	PRIMARY KEY (id)
);
