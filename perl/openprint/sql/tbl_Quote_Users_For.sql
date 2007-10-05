DROP TABLE tbl_Quote_Users_For;

CREATE TABLE tbl_Quote_Users_For (
	QuoteIndex		INT4 NOT NULL, FOREIGN KEY (QuoteIndex) REFERENCES tbl_Quotes (Index),
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

