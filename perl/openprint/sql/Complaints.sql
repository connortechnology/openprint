CREATE SEQUENCE complaints_id_seq;

CREATE TABLE Complaints (
	id	INTEGER NOT NULL default nextval('complaints_id_seq'),
	company_id	INTEGER, FOREIGN KEY (company_id) REFERENCES Company (index),
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES Users (index),
	company_name	TEXT,
	contact_name	TEXT,
	ponum			TEXT,
	docket			TEXT,
	howreceived		TEXT,
	description		TEXT,
	comments		TEXT,
	carnumber		TEXT,
	created_on		timestamp with time zone not null default NOW(),
	PRIMARY KEY (id)
);
