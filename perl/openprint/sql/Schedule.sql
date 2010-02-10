DROP TABLE IF EXISTS Schedule;

CREATE TABLE Schedule (
	id					SERIAL,
	Equipment_Id		INTEGER NOT NULL, FOREIGN KEY (Equipment_ID) REFERENCES tbl_Equipment (lngIndex),
	ProjectIndex		INTEGER NOT NULL, FOREIGN KEY (ProjectIndex) REFERENCES tbl_Projects (Index),
	ServiceIndex		INTEGER NOT NULL,
	StartTime			TIMESTAMP WITH TIME ZONE NOT NULL,
	starttime_locked	boolean,
	EndTime				TIMESTAMP WITH TIME ZONE NOT NULL,
	endtime_locked		boolean,
	RunTime				INTERVAL NOT NULL,
	runtime_locked		boolean,
	speed				INTEGER,
	PRIMARY KEY (id)
);
