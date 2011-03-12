
DROP TABLE IF EXISTS Messages;
CREATE TABLE Messages (
	id 		SERIAL,
	subject	TEXT,
	body	TEXT,
	from_id		INTEGER NOT NULL, FOREIGN KEY (from_id) REFERENCES Users (id),
	reply_to	INTEGER, FOREIGN KEY (reply_to) REFERENCES Messages (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	sent_on		TIMESTAMP WITH TIME ZONE,
	PRIMARY KEY (id)
);

CREATE TABLE Messages_to (
	message_id	INTEGER NOT NULL, FOREIGN KEY (message_id) REFERENCES Messages (id),
	to_id		INTEGER NOT NULL, FOREIGN KEY (to_id) REFERENCES Users (id),
	deleted		BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (to_id, message_id)
) 
