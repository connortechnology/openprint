
DROP TABLE IF EXISTS EmailCampaigns;
CREATE TABLE EmailCampaigns (
	id	SERIAL NOT NULL,
	Name	TEXT NOT NULL,
	Query	TEXT NOT NULL,
	Interval	INTERVAL NOT NULL,
	Active	CHAR(1) default 'Y',
	TimesToSend	INTEGER,
	email_subject	TEXT,
	email_text	TEXT,
	email_from	TEXT,
	LastRun	TIMESTAMP WITH TIME ZONE,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default now(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default now(),
	nextrun		TIMESTAMP WITH TIME ZONE,
	PRIMARY KEY (id)
);
