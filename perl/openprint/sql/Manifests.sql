CREATE TABLE Manifests (
	id	TEXT NOT NULL,
	received_on	timestamp with time zone NOT NULL default NOW(),
	updated_on	timestamp with time zone NOT NULL default NOW(),
	created_on	timestamp with time zone NOT NULL default NOW(),
	PRIMARY KEY (id)
);

CREATE TABLE ManifestContents (
	id	SERIAL NOT NULL,
	manifest_id	TEXT NOT NULL, FOREIGN KEY (manifest_id) REFERENCES Manifests (id),
	skid_id		INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES Skids (id),
	quantity	INTEGER NOT NULL,
	cost		FLOAT,	
	docket		INTEGER,
	PRIMARY KEY (id)
);
