DROP TABLE IF EXISTS Quotes;


CREATE TABLE Quotes (
	id				SERIAL NOT NULL,
	company_id		INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	user_id			INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
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
	currency_id			INTEGER, FOREIGN KEY (currency_id) REFERENCES Currencies (id),
  reference     TEXT,
  comments     TEXT,
	deleted				BOOLEAN NOT NULL DEFAULT False,
  for_company_id INTEGER, FOREIGN KEY (for_company_id) REFERENCES Companies(id),
	PRIMARY KEY (id)
);

