DROP TABLE IF EXISTS squarespace_settings;

CREATE TABLE squarespace_settings (
	id		SERIAL,
	site	TEXT,
	data	TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX squarespace_settings_site_idx ON squarespace_settings (site);

CREATE TABLE squarespace_log (
	id	SERIAL,
	site_id	INTEGER NOT NULL, FOREIGN KEY (site_id) REFERENCES squarespace_settings (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL,
	parameters	TEXT,
	PRIMARY KEY (id)	
);
