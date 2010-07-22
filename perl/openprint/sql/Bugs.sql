DROP TABLE IF EXISTS Bugs;
CREATE TABLE Bugs (
	id	SERIAL,
	owner_id	INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (id),
	company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	project_Id	INTEGER NOT NULL, FOREIGN KEY (project_id) REFERENCES Projects (id),
	description	TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	status_id	INTEGER, FOREIGN KEY (status_id) REFERENCES bug_statuses (id),
	PRIMARY KEY (id)
);
