DROP TABLE Bindery_Schedule;

CREATE TABLE Bindery_Schedule (
	ProjectIndex	INTEGER NOT NULL, FOREIGN KEY (ProjectIndex) REFERENCES Projects (Index),
	ServiceIndex		INTEGER NOT NULL,
	StartTime	TIMESTAMP WITH TIME ZONE NOT NULL,
	Runtime	INTERVAL NOT NULL,
	servicetype_id		INTEGER, FOREIGN KEY (servicetype_id) REFERENCES tbl_Service_Types (lngIndex),
	PRIMARY KEY (StartTime, servicetype_id, ProjectIndex)
);
