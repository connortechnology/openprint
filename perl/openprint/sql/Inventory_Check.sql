DROP SEQUENCE InventoryCheck_id_seq;
CREATE SEQUENCE InventoryCheck_id_seq;

DROP TABLE InventoryChecks;

CREATE TABLE InventoryChecks (
	id	INTEGER NOT NULL default nextval('InventoryCheck_id_seq'),
	created_on	timestamp with time zone NOT NULL default NOW(),
	PRIMARY KEY (id)
);

DROP TABLE InventoryCheckEntries;
CREATE TABLE InventoryCheckEntries (
	ic_id	INTEGER NOT NULL, FOREIGN KEY (ic_id) REFERENCES InventoryChecks (id),
	skid_id	INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES Skids (id),
	paper_id	INTEGER NOT NULL, FOREIGN KEY (paper_id) REFERENCES Papers (id),
	quantity	INTEGER NOT NULL,
	location	TEXT NOT NULL,
	created_on	timestamp with time zone NOT NULL default NOW(),
	operator_id	INTEGER NOT NULL, FOREIGN KEY (operator_id) REFERENCES tbl_Customer_Users (lngUserID)
);

