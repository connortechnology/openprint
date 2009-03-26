DROP SEQUENCE iF EXISTS Users_Id_seq;
DROP TABLE iF EXISTS Users;

CREATE TABLE Users (
/* tablename, etc too long.	So we had to truncate it in here... it all works automatically elsewhere */
	Index		SERIAL,
	company_id	INTEGER NOT NULL,
	strEmail		TEXT NOT NULL, UNIQUE(strEmail), 
	strPassword		TEXT NOT NULL,
	strTitle		TEXT,
	strFirstName	TEXT NOT NULL,
	strLastName		TEXT NOT NULL,
	strSalutation	varchar(4),
	strPhone		TEXT,
	strExt			TEXT,
	strFax			TEXT,
	dtmDateEntered	timestamp with time zone NOT NULL,
	dtmLastModified timestamp with time zone NOT NULL,
	chrType			char(1) NOT NULL,
	ysnChangePassword char(1) DEFAULT 'Y',
	ysnMailingList	char(1) DEFAULT 'N',
	ysnAccountActivation	CHAR(1) DEFAULT 'N',
	dblCommission			NUMERIC(6,4),
	strCustomGreeting		TEXT,
	ysnAdministrator		CHAR(1) DEFAULT 'N',
	ysnHTMLEmails			CHAR(1),
	strEmployeeType			TEXT,
	strMailServerUsername	TEXT,
	strMailServerPassword	TEXT,
	LastLogin				timestamp with time zone,
	notes					TEXT,
	purchasing_limit		float,
	purchasing_total_limit	float,
	PRIMARY KEY (Index)
);
CREATE INDEX UserEmail_Index ON Users (strEmail);
alter table Users add foreign key (Company_Id) REFERENCES Companies (Id);
