DROP TABLE IF EXISTS Bindery_Schedule;

CREATE TABLE Bindery_Schedule (
	ProjectIndex	INTEGER NOT NULL, FOREIGN KEY (ProjectIndex) REFERENCES Projects (id),
	ServiceIndex		INTEGER NOT NULL,
	StartTime	TIMESTAMP WITH TIME ZONE NOT NULL,
	Runtime	INTERVAL NOT NULL,
	servicetype_id		INTEGER, FOREIGN KEY (servicetype_id) REFERENCES Service_Types (id),
	PRIMARY KEY (StartTime, servicetype_id, ProjectIndex)
);
