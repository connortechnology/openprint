
DROP TABLE IF EXISTS Conversations;
CREATE TABLE Conversations (
	id 		SERIAL,
	subject	TEXT,
	created_by	INTEGER,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	deleted	BOOLEAN NOT NULL default false,
	PRIMARY KEY (id)
);
