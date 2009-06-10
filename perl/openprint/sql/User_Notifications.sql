DROP TABLE IF EXISTS User_Notifications;
DROP TABLE User_Notification_Types;

CREATE TABLE User_Notification_Types (
	id SERIAL,
	name TEXT,
	PRIMARY KEY (id)
);

INSERT INTO User_Notification_Types (name) VALUES ('Client File Uploads');

CREATE TABLE User_Notifications (
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (Index),
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES User_Notification_Types (id),
	value	TEXT,
	PRIMARY KEY (user_id, type_id)
);
