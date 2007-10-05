DROP TABLE HelpDesk;

DROP SEQUENCE HelpDesk_Id_seq;
CREATE SEQUENCE HelpDesk_Id_seq;

CREATE TABLE HelpDesk (
	id INTEGER DEFAULT nextval('HelpDesk_id_seq'),
	company_id		INTEGER, FOREIGN KEY (company_id) REFERENCES company (index),
	User_Id			INTEGER, FOREIGN KEY (User_Id) REFERENCES Users (index),
	dtmRequestDate	timestamp with time zone NOT NULL,
	blbDescription	TEXT,
	strCompanyName	TEXT,
	strTitle		TEXT,
	strFirstName	TEXT,
	strLastName		TEXT,
	strAddress		TEXT,
	strAddress2		TEXT,
	strCity			TEXT,
	strStateProv	TEXT,
	strPostalCode	TEXT,
	strCountry		TEXT,
	strPhone		TEXT,
	strExtension	TEXT,
	strEmail		TEXT,
	blbQuestion		TEXT,
	blbResponse TEXT,
	chrMethod char(1),
	ysnReviewed CHAR(1) DEFAULT 'N' NOT NULL,
	PRIMARY KEY( Id )
);


