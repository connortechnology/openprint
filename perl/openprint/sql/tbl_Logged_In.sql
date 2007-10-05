DROP TABLE tbl_Logged_In;

CREATE TABLE tbl_Logged_In (
	strSessionID		char(10) DEFAULT '' NOT NULL, 
	chrSite			char(1),
	UserIndex			INT4, FOREIGN KEY (UserIndex) REFERENCES Users (Index),
	CompanyIndex		INT4, FOREIGN KEY (CompanyIndex) REFERENCES Company (Index),
	strEmail			TEXT,
	chrUserType		char(1),
	dtmLastAccessed	TIMESTAMP WITH TIME ZONE,
	PRIMARY KEY (strSessionID, chrSite)
);

