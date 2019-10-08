DROP TABLE IF EXISTS CLaim_Assets;

CREATE TABLE CLaim_Assets (
	asset_id	INTEGER NOT NULL, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	claim_id	INTEGER NOT NULL, FOREIGN KEY (claim_id) REFERENCES Claims (id),
	PRIMARY KEY (claim_id,asset_id)
);
