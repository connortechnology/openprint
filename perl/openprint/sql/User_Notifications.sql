CREATE TABLE User_Notifications (
	id	SERIAL,
	company_id	INTEGER, FOREIGN KEY (company_id) REFERENCES Companies (id),
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES User_Notification_Types (id),
	value	TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX user_notifications_user_idx on user_notifications (user_id,type_id);
CREATE INDEX user_notifications_company_idx on user_notifications (type_id,company_id);
