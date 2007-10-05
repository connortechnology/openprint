DROP SEQUENCE Address_Index_seq;
DROP TABLE tbl_Addresses;

CREATE SEQUENCE Address_Index_seq;
CREATE TABLE tbl_Addresses (
	lngIndex			INT4 DEFAULT nextval('Address_Index_seq'),
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

