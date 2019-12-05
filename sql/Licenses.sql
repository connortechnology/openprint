CREATE TABLE Licenses (
	id	SERIAL,
	serialkey	TEXT,
	max_uses	integer,
	purchased_on	DATE,
	expires_on	DATE,
	software_id	INTEGER, FOREIGN KEY (software_id) REFERENCES Software (id),
	comment		TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	PRIMARY KEY (id)	
);
