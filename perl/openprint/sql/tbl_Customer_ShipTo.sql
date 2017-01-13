DROP TABLE tbl_Customer_ShipTo;

DROP SEQUENCE tbl_Customer_ShipTo_lngShipID_seq;
CREATE SEQUENCE tbl_Customer_ShipTo_lngShipID_seq;

CREATE TABLE tbl_Customer_ShipTo (
  lngShipID INT4 DEFAULT nextval('tbl_Customer_ShipTo_lngShipID_s'),
  lngCustomerID INT4 NOT NULL,
  strCompanyName	TEXT,
  strSalutation		TEXT,
  strFirstName		TEXT,
  strLastName		TEXT,
  strAddress		TEXT,
  strAddress2		TEXT,
  strCity			TEXT,
  strState			char(2),
  strZip			char(12),
  strCountry		char(2),
  strPhoneNumber	TEXT,
  strExtension		char(4),
  strFax			TEXT,
  strEmail			TEXT,
  PRIMARY KEY (lngShipID)
);
