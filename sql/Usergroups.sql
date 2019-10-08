CREATE TABLE usergroups (
	id	SERIAL NOT NULL,
	name	TEXT,
	description	TEXT, /* Mostly just help text */
	duration	INTERVAL,
	asset_id	INTEGER, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	PRIMARY KEY (id)
);
