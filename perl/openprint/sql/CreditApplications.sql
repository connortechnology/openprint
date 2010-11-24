DROP TABLE IF EXISTS CreditApplications;

CREATE TABLE CreditApplcations ( 
	id					SERIAL,
	company_id			INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCS USers (id),
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
	PRIMARY KEY (id)
);
