DROP TABLE IF EXISTS Complaints;

CREATE TABLE Complaints (
	id			SERIAL,
	company_id	INTEGER, FOREIGN KEY (company_id) REFERENCES Companies (id),
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES Users (id),
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
