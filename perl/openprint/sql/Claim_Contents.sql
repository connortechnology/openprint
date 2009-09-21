DROP TABLE IF EXISTS Claim_Contents;

CREATE TABLE Claim_Contents (
	id	SERIAL,
	claim_id	INTEGER NOT NULL, FOREIGN KEY (claim_id) REFERENCES Claims (id),
	cost		float,
	cost_units	text,
	skid_id		INTEGER, 	FOREIGN KEY (skid_id) REFERENCES Skids (id),
	quantity	INTEGER,	
	reason		TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX Claim_Contents_claim_id_idx on Claim_Contents (claim_id);

