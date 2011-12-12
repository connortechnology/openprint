DROP TABLE IF EXISTS Schedule;

CREATE TABLE Schedule (
	id					SERIAL,
	Equipment_Id		INTEGER NOT NULL, FOREIGN KEY (Equipment_ID) REFERENCES tbl_Equipment (id),
	ProjectIndex		INTEGER NOT NULL, FOREIGN KEY (ProjectIndex) REFERENCES Projects (id),
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
	servicetype_id		INTEGER,
	pertains_id			INTEGER[],
	tentative			BOOLEAN,
	stock_verified		BOOLEAN NOT NULL default false,
	stock				TEXT,
	created_on			TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	PRIMARY KEY (id)
);
