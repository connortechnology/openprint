
DROP TABLE IF EXISTS RFIDTagHistory;
DROP TABLE IF EXISTS RFIDTags;
DROP TABLE IF EXISTS RFIDTagTypes;
DROP TABLE IF EXISTS RFIDScanners;

CREATE TABLE RFIDTagTypes (
	id	 SERIAL NOT NULL,
	name	TEXT,
	PRIMARY KEY (id)
);
table create unique index rfidtagtypes_name_idx on rfidtagtypes (name);

CREATE TABLE RFIDTagActions (
	id	 SERIAL NOT NULL,
	name	TEXT,
	PRIMARY KEY (id)
);

CREATE TABLE RFIDTags (
	id	TEXT NOT NULL,
	location_id	INTEGER, FOREIGN KEY (location_id) REFERENCES Locations (id),
	type_id		INTEGER, FOREIGN KEY (type_id) REFERENCES RFIDTagTypes (id),
	action_id	INTEGER, FOREIGN KEY (action_id) REFERENCES RFIDTagActions (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	PRIMARY KEY (id)
);


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



DROP TABLE IF EXISTS RFIDTagHistory;
CREATE TABLE RFIDTagHistory (
	id	SERIAL NOT NULL,
	rfidtag_id	TEXT NOT NULL, FOREIGN KEY (rfidtag_id) REFERENCES RFIDTags (id),
	scanner_id	INTEGER, FOREIGN KEY (scanner_id) REFERENCES RFIDScanners (id),
	location_id	INTEGER NOT NULL, FOREIGN KEY (location_id) REFERENCES Locations (id),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	PRIMARY KEY (id)
);

create index rfidtaghistory_updated_on_scanner_idx on rfidtaghistory (updated_on,scanner_id);
create index rfidtaghistory_rfidtag_idx on rfidtaghistory (rfidtag_id);
