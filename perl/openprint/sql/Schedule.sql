DROP TABLE IF EXISTS Schedule;

CREATE TABLE Schedule (
	id					SERIAL,
	Equipment_Id		INTEGER NOT NULL, FOREIGN KEY (Equipment_ID) REFERENCES tbl_Equipment (lngindex),
	ProjectIndex		INTEGER NOT NULL, FOREIGN KEY (ProjectIndex) REFERENCES Projects (Id),
	service_id			INTEGER[],
	StartTime			TIMESTAMP WITH TIME ZONE NOT NULL,
	starttime_locked	boolean,
	EndTime				TIMESTAMP WITH TIME ZONE NOT NULL,
	endtime_locked		boolean,
	RunTime				INTERVAL NOT NULL,
	runtime_locked		boolean,
	speed				INTEGER,
	comment				TEXT,
	operator_id			INTEGER, FOREIGN KEY (operator_id) REFERENCES Users (id),
	PRIMARY KEY (id)
);
