DROP TABLE IF EXISTS Host_Notifications;

CREATE TABLE Host_Notifications (
	host_id	INTEGER NOT NULL, FOREIGN KEY (host_id) REFERENCES Hosts (id),
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	PRIMARY KEY (host_id,user_id)
);
