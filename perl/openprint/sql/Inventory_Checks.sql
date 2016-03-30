
DROP TABLE Inventory_Checks;

CREATE TABLE Inventory_Checks (
	id	SERIAL,
	created_on	timestamp with time zone NOT NULL default NOW(),
	name		TEXT,
	started_on	date,
	ended_on	date,
	scanner_id	INTEGER, FOREIGN KEY (scanner_id) REFERENCES RFIDScanners (id),
	deleted		BOOLEAN NOT NULL DEFAULT false,
	PRIMARY KEY (id)
);

DROP TABLE Inventory_Check_Entries;
CREATE TABLE Inventory_Check_Entries (
	ic_id	INTEGER NOT NULL, FOREIGN KEY (ic_id) REFERENCES InventoryChecks (id),
	skid_id	INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES Skids (id),
	rfidtag_id	TEXT,
	paper_id	INTEGER, FOREIGN KEY (paper_id) REFERENCES Papers (id),
	quantity	INTEGER,
	dimension1	float,
	dimension2	float,
	notes		TEXT,
	location_id	INTEGER NOT NULL, FOREIGN KEY (location_id) REFERENCES Locations (id),
	created_on	timestamp with time zone NOT NULL default NOW(),
	operator_id	INTEGER NOT NULL, FOREIGN KEY (operator_id) REFERENCES Users (id)
);

