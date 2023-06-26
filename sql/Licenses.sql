DROP TABLE IF EXISTS Licenses CASCADE;

CREATE TABLE Licenses (
	id	SERIAL,
  company_id INTEGER, FOREIGN KEY(company_id) REFERENCES Companies(id),
  site_id     INTEGER, FOREIGN KEY(site_id) REFERENCES Sites(id),
	serialkey	TEXT,
  hash      TEXT,
	max_uses	integer,
	purchased_on	DATE,
	expires_on	DATE,
	software_id	INTEGER, FOREIGN KEY (software_id) REFERENCES Software (id),
	comment		TEXT,
  features_json  TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	PRIMARY KEY (id)	
);
