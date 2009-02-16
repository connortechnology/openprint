DROP SEQUENCE IF EXISTS Address_Index_seq;
DROP TABLE IF EXISTS tbl_Addresses;

CREATE SEQUENCE Address_Index_seq;
CREATE TABLE tbl_Addresses (
	lngIndex			INTEGER DEFAULT nextval('Address_Index_seq'),
	company_id			INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	strCompanyName		TEXT,
	strFirstName		TEXT,
	strLastName			TEXT,
	strSalutation		TEXT,
	strAddress1			TEXT,
	strAddress2			TEXT,
	strCity				TEXT,
	strStateProvince	TEXT,
	strPostalCode		TEXT,
	strCountry			TEXT,
	strPhone			TEXT,
	strExtension		CHAR(4),
	strFax				TEXT,
	strEmail			TEXT,
	PRIMARY KEY (lngIndex)
);

