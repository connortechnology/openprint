CREATE TABLE User_Notification_Types (
	id SERIAL,
	name TEXT,
	sort	INTEGER,
	PRIMARY KEY (id)
);

INSERT INTO User_Notification_Types (name) VALUES ('Client File Uploads');
