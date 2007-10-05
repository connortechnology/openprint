DROP TABLE EmailCampaignSent;

CREATE TABLE EmailCampaign_Sent (
	campaign_id	INTEGER NOT NULL, FOREIGN KEY (campaign_id) REFERENCES EmailCampaigns (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (Index),
	EmailSentOn		TIMESTAMP WITH TIME ZONE NOT NULL default 'NOW()',
	NumEmailSent	INTEGER NOT NULL,
	MarkedForDeletion	CHAR(1) NOT NULL default 'N',
	PRIMARY KEY( campaign_id, user_id )
);
