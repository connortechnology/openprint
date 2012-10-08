CREATE TABLE Blocklist (
	blockee	INTEGER NOT NULL, FOREIGN KEY (blockee) REFERENCES Users (id),
	blocker	INTEGER NOT NULL, FOREIGN KEY (blocker) REFERENCES Users (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	reason	TEXT,
	PRIMARY KEY (blockee,blocker)
);
