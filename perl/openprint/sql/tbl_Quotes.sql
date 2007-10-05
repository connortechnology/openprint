DROP TABLE tbl_Quotes;


CREATE TABLE tbl_Quotes (
	Index				INT4 NOT NULL,
	strSessionID		varchar(10) NOT NULL,
	CompanyIndex		INT4 NOT NULL, FOREIGN KEY (CompanyIndex) REFERENCES Company (Index),
	UserIndex			INT4 NOT NULL, FOREIGN KEY (UserIndex) REFERENCES Users (Index),
    dblModification1	NUMERIC(20,2),
    dblModification2	NUMERIC(20,2),
    dblModification3	NUMERIC(20,2),
	curTotalSale1		NUMERIC(20,2),
	curTotalSale2		NUMERIC(20,2),
	curTotalSale3		NUMERIC(20,2),
	dtmQuoteDate		timestamp with time zone NOT NULL,
	dtmLastModified		timestamp with time zone NOT NULL,
	strStatus			TEXT,
	strCustomerComments			TEXT,	/* Comments included in the emails */
	strAdministratorComments	TEXT,	/* Comments included in the emails */
	strAdministratorName		TEXT,
	strCurrencyName		TEXT,
	strCurrencySymbol	TEXT,
	PRIMARY KEY (Index)
);

