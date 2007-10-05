DROP TABLE tbl_Credit_App;
DROP SEQUENCE lngCreditAppIndex_seq;
CREATE SEQUENCE lngCreditAppIndex_seq;

CREATE TABLE tbl_Credit_App ( 
    lngIndex			INT4 NOT NULL DEFAULT nextval('lngCreditAppIndex_seq'),
    lngCustomerIndex	INT4 NOT NULL,
	lngUserIndex		INT4 NOT NULL,
	strSignature		TEXT,
	ysnFinancialStatementAvailable	CHAR(1) default 'N',
	strFirstOrderValue	TEXT,
	strAnnualPurchases	TEXT,
    dblCreditLimit		NUMERIC(10,2),
	lngTerms			INT4,
	dtmCreationDate		TIMESTAMP,
	strAccountsPayableContact	TEXT,
	strStatus			TEXT,
	lngGrantedTerms		INT4,
	dblGrantedCreditLimit	NUMERIC(10,2),
	dblGrantedDownpayment	NUMERIC(10,2),
	PRIMARY KEY (lngIndex)
);
