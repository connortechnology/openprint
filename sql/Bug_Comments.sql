DROP TABLE IF EXISTS Bug_Comments;

CREATE TABLE Bug_Comments (
	id	SERIAL,
	bug_id	INTEGER NOT NULL, FOREIGN KEY (bug_id) REFERENCES Bugs (id),
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	text		TEXT,
	status		INTEGER,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	PRIMARY KEY (id)
);
