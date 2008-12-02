
DROP TABLE IF EXISTS EmailCampaigns;
CREATE TABLE EmailCampaigns (
	id	SERIAL NOT NULL,
	Name	TEXT NOT NULL,
	Query	TEXT NOT NULL,
	Interval	INTERVAL NOT NULL,
	Active	CHAR(1) default 'Y',
	TimesToSend	INTEGER,
	EmailText	TEXT,
	FromEmail	TEXT,
	LastRun	TIMESTAMP WITH TIME ZONE,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default now(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default now(),
	PRIMARY KEY (id)
);
