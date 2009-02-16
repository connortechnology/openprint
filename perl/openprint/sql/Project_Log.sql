
DROP TABLE Project_Log;

CREATE TABLE Project_Log (
	Project_Id	INTEGER	NOT NULL, FOREIGN KEY(Project_Id) REFERENCES Projects (Index),
	Company_id	INTEGER, FOREIGN KEY(Company_id) REFERENCES Companies (id),
	User_Id		INTEGER, FOREIGN KEY(User_id) REFERENCES Users (id),
	dtmTimestamp		timestamp with time zone NOT NULL default(NOW()),
	Description			TEXT,
	PRIMARY KEY (Project_Id,dtmTimestamp)
);
