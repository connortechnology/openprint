DROP TABLE IF EXISTS usergroups;
CREATE TABLE usergroups (
	id	SERIAL NOT NULL,
	name	TEXT,
	duration	INTERVAL,
	asset_id	INTEGER, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	PRIMARY KEY (id)
);
