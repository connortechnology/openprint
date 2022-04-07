CREATE TABLE EmailCampaign_Subscriptions (
	id SERIAL,
	campaign_id	INTEGER NOT NULL, FOREIGN KEY (campaign_id) REFERENCES EmailCampaigns (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	PRIMARY KEY(id)
);

CREATE INDEX emailcampaign_subscriptions_idx on emailcampaign_subscriptions (campaign_id,user_id);
