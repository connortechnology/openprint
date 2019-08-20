DROP TABLE IF EXISTS ProductionFeedback;

CREATE TABLE ProductionFeedback (
	id SERIAL,
	project_id	INTEGER NOT NULL, FOREIGN KEY (project_id) REFERENCES Projects (id),
	service_id	INTEGER NOT NULL,
	starting_on	timestamp with time zone NOT NULL,
	ending_on	timestamp with time zone NOT NULL,
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES Users (id),
	comment		TEXT,
	PRIMARY KEY (id)
);
