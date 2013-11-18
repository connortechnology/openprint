DROP TABLE tbl_Credit_Card_Info;

CREATE TABLE tbl_Credit_Card_Info (
    lngIndex		INT8 NOT NULL,
    strCCExpiryYear		char(4) NOT NULL,
    strCCExpiryMonth	char(2) NOT NULL,
    strType			TEXT, /* American Express is 15 chars */
    strCCNumber		TEXT NOT NULL,
	strCompany		TEXT,
    strFirstName	TEXT NOT NULL,
    strLastName		TEXT NOT NULL,
	strEmail		TEXT,
	strAddress		TEXT,
	strCity			TEXT,
	strState		TEXT,	
	strPostalCode	TEXT,
	strCountry		TEXT,
	strPhone		TEXT,
	strFax			TEXT,
	strPONum		TEXT,
    dtmCreatedDate	datetime NOT NULL,
	PRIMARY KEY (lngIndex)
);

