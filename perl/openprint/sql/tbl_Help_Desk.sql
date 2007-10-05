DROP TABLE tbl_Help_Desk;

DROP SEQUENCE HelpDeskIndex_seq;
CREATE SEQUENCE HelpDeskIndex_seq;

CREATE TABLE tbl_Help_Desk (
	lngIndex INT4 DEFAULT nextval('HelpDeskIndex_seq'),
	lngCustomerIndex	INT4, /*FOREIGN KEY (lngCustomerIndex) REFERENCES tbl_Customer (lngCustomerID),*/
	lngUserIndex		INT4, /*FOREIGN KEY (lngUserIndex) REFERENCES tbl_Customer_Users (lngUserID),*/
	dtmRequestDate		datetime NOT NULL,
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
	PRIMARY KEY( lngIndex )
);


