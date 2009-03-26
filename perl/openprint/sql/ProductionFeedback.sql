DROP TABLE IF EXISTS ProductionFeedback;

CREATE TABLE ProductionFeedback (
	id SERIAL,
	project_id	INTEGER NOT NULL, FOREIGN KEY (project_id) REFERENCES tbl_Projects (index),
	service_id	INTEGER NOT NULL,
	starting_on	timestamp with time zone NOT NULL,
	ending_on	timestamp with time zone NOT NULL,
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES Users (index),
	comment		TEXT,
	PRIMARY KEY (id)
);
