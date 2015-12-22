CREATE TABLE tbl_Quote_Users_By (
	quote_id		INTEGER NOT NULL, FOREIGN KEY (quote_id) REFERENCES Quotes (id),
	strCompanyName	TEXT,
	strFirstName	TEXT,
	strLastName		TEXT,
	strTitle		TEXT,
	strSalutation	TEXT,
	strAddress		TEXT,
	strAddress2		TEXT,
	strCity			TEXT,
	strState		TEXT,
	strCountry		TEXT,
	strPostalCode	TEXT,
	strPhone		TEXT,
	strExt			TEXT,
	strFax			TEXT,
	strEmail		TEXT
);

