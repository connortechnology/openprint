
CREATE TABLE ManifestContents (
	id	SERIAL NOT NULL,
	manifest_id	INTEGER NOT NULL, FOREIGN KEY (manifest_id) REFERENCES Manifests (id),
	skid_id		INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES Skids (id),
	quantity	INTEGER NOT NULL,
	cost		FLOAT,	
	docket		INTEGER,
	location_id	INTEGER, FOREIGN KEY (location_id) REFERENCES Locations (id),
    type_id		INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES Manifest_Content_Types (id),
    rfidtag_id	TEXT,
	po_id		INTEGER, FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
    manufacturers_id	TEXT,
	PRIMARY KEY (id)
);

create  index manifestcontents_docket_idx on manifestcontents (docket);
create  index manifestcontents_po_id_idx on manifestcontents (po_id);
create  index manifestcontents_rfidtag_id_idx on manifestcontents (rfidtag_id);
create  index manifestcontents_manifest_id_idx on manifestcontents (manifest_id);
