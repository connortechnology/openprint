
DROP TABLE IF EXISTS Messages_to;
DROP TABLE IF EXISTS Message_to;
DROP TABLE IF EXISTS Messages;
CREATE TABLE Messages (
	id 		SERIAL,
	body	TEXT,
	from_id		INTEGER, FOREIGN KEY (from_id) REFERENCES Users (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	sent_on		TIMESTAMP WITH TIME ZONE,
	conversation_id	INTEGER NOT NULL, FOREIGN KEY (conversation_id) REFERENCES Messages (id),
	PRIMARY KEY (id)
);

CREATE TABLE Message_to (
	message_id	INTEGER NOT NULL, FOREIGN KEY (message_id) REFERENCES Messages (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	deleted		BOOLEAN NOT NULL DEFAULT FALSE,
	viewed		BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (user_id, message_id)
) 
