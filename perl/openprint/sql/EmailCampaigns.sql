
DROP SEQUENCE EmailCampaign_Id_seq;
CREATE SEQUENCE EmailCampaign_Id_seq;

DROP TABLE EmailCampaigns;
CREATE TABLE EmailCampaigns (
	id	INTEGER NOT NULL default nextval('EmailCampaign_id_seq'),
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
