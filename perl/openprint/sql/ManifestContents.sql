
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
    manufacturers_id	TEXT,
	PRIMARY KEY (id)
);
