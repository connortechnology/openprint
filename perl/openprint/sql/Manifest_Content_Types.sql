DROP TABLE IF EXISTS Manifest_Content_Types;

CREATE TABLE Manifest_Content_Types (
	id	SERIAL,
	manifest_id	INTEGER NOT NULL, FOREIGN KEY (manifest_id) REFERENCES Manifests (id),
	cost		float,
	po_id		INTEGER,	FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
	paper_id	INTEGER, 	FOREIGN KEY (paper_Id) REFERENCES Papers (id),
	supplier_invoice	TEXT,
	docket		INTEGER,
	PRIMARY KEY (id)
);

CREATE INDEX Manifest_Content_Types_manifest_id_idx on Manifest_Content_Types (manifest_id);

