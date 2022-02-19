CREATE TABLE EmailCampaign_Sent (
	id SERIAL,
	campaign_id	INTEGER NOT NULL, FOREIGN KEY (campaign_id) REFERENCES EmailCampaigns (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	EmailSentOn		TIMESTAMP WITH TIME ZONE NOT NULL default 'NOW()',
	NumEmailSent	INTEGER NOT NULL,
	MarkedForDeletion	CHAR(1) NOT NULL default 'N',
	PRIMARY KEY( id )
);

CREATE INDEX emailcampaign_sent_idx on emailcampaign_sent (campaign_id,user_id);
