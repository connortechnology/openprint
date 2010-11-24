DROP TABLE iF EXISTS Users;

CREATE TABLE Users (
/* tablename, etc too long.	So we had to truncate it in here... it all works automatically elsewhere */
	id		SERIAL,
	company_id	INTEGER NOT NULL,
	email		TEXT NOT NULL, UNIQUE(email), 
	password		TEXT NOT NULL,
	title		TEXT,
	firstName	TEXT NOT NULL,
	lastName		TEXT NOT NULL,
	salutation	varchar(4),
	phone		TEXT,
	fax			TEXT,
	created_on	timestamp with time zone NOT NULL,
	updated_on timestamp with time zone NOT NULL,
	type			char(1) NOT NULL,
	ysnChangePassword char(1) DEFAULT 'Y',
	ysnMailingList	char(1) DEFAULT 'N',
	web_active	CHAR(1) DEFAULT 'N',
	dblCommission			NUMERIC(6,4),
	strCustomGreeting		TEXT,
	ysnAdministrator		CHAR(1) DEFAULT 'N',
	notes					TEXT,
	purchasing_limit		float,
	purchasing_total_limit	float,
	deleted					BOOLEAN NOT NULL default false,
	PRIMARY KEY (Index)
);
CREATE INDEX users_email_idx ON Users (strEmail);
alter table Users add foreign key (Company_Id) REFERENCES Companies (Id);
ALTER TABLE Companies add FOREIGN KEY (Salesrep_id) REFERENCES Users (id);
