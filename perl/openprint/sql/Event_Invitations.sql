DROP TABLE IF EXISTS Event_Invitations;

CREATE TABLE Event_Invitations (
	event_id	INTEGER NOT NULL, FOREIGN KEY (event_id) REFERENCES Events (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	PRIMARY KEY (event_id, user_id)
);
