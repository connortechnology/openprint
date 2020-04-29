DROP TABLE IF EXISTS Event_Attendance;

CREATE TABLE Event_Attendance (
	event_id	INTEGER NOT NULL, FOREIGN KEY (event_id) REFERENCES Events (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	attending	boolean,
	PRIMARY KEY (event_id, user_id)
);
