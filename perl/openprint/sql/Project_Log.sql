
DROP TABLE Project_Log;

CREATE TABLE Project_Log (
	Project_Id	INTEGER	NOT NULL, FOREIGN KEY(Project_Id) REFERENCES tbl_Projects (Index),
	Company_id	INTEGER, FOREIGN KEY(Company_id) REFERENCES Company (Index),
	User_Id		INTEGER, FOREIGN KEY(User_id) REFERENCES Users (Index),
	dtmTimestamp		timestamp with time zone NOT NULL default(NOW()),
	Description			TEXT,
	PRIMARY KEY (Project_Id,dtmTimestamp)
);
