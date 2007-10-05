DROP TABLE EmailCampaign_Log;
CREATE TABLE EmailCampaign_Log (
	campaign_id	INTEGER NOT NULL, FOREIGN KEY (campaign_id) REFERENCES EmailCampaigns (id),
	log				TEXT,
	time			TIMESTAMP WITH TIME ZONE NOT NULL
);
