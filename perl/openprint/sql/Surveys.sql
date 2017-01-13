
CREATE TABLE Surveys (
	id			SERIAL,
	name		TEXT,
	description	TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	created_by	INTEGER NOT NULL, FOREIGN KEY (created_by) REFERENCES Users (id),
	PRIMARY KEY (id)
);
