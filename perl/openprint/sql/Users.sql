CREATE TABLE Users (
/* tablename, etc too long.	So we had to truncate it in here... it all works automatically elsewhere */
	id		SERIAL,
	company_id	INTEGER,
	email		TEXT NOT NULL, UNIQUE(email), 
	email_valid	BOOLEAN,
	password		TEXT,
	title		TEXT,
	firstName	TEXT,
	lastName		TEXT,
	salutation	varchar(4),
	phone		TEXT,
	fax			TEXT,
	sms			TEXT,
	mobile		text,
	created_on	timestamp with time zone NOT NULL default now(),
	updated_on timestamp with time zone NOT NULL default now(),
	type			char(1) NOT NULL,
	ysnChangePassword char(1) DEFAULT 'Y',
	ysnMailingList	char(1) DEFAULT 'N',
	web_active	CHAR(1) DEFAULT 'N',
	ftp_active	boolean not null default false,
	ftp_root	TEXT not null default '',
	dblCommission			NUMERIC(6,4),
	greeting		TEXT,
	ysnAdministrator		CHAR(1) DEFAULT 'N',
	notes					TEXT,
	purchasing_limit		float,
	purchasing_total_limit	float,
	wage					float,
	email_quotes_to_myself	boolean not null default false,
	quote_level				integer,
	howdidyouhearaboutus	text,
	howdidyouhearaboutusother	text,
	deleted					BOOLEAN NOT NULL default false,
	asset_id				INTEGER,
	password_changed_on TIMESTAMP WITH TIME ZONE,
	PRIMARY KEY (id)
);
CREATE INDEX users_email_idx ON Users (email);
ALTER TABLE users ADD FOREIGN KEY (company_id) REFERENCES Companies (Id);
ALTER TABLE Companies ADD FOREIGN KEY (salesrep_id) REFERENCES Users (id);

INSERT INTO Users (company_id, email, email_valid, password, firstName, lastname, web_active, ysnAdministrator, type ) values ( 1, 'iconnor@connortechnology.com', true, 'XV35me', 'Isaac', 'Connor', 'Y', 'Y', 'A' );
