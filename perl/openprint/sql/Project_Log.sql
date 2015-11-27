
CREATE TABLE Project_Log (
	project_id	INTEGER	NOT NULL, FOREIGN KEY(project_id) REFERENCES Projects (id),
	company_id	INTEGER, FOREIGN KEY(company_id) REFERENCES Companies (id),
	user_id		INTEGER, FOREIGN KEY(user_id) REFERENCES Users (id),
	dtmTimestamp		timestamp with time zone NOT NULL default(NOW()),
	Description			TEXT
);

CREATE INDEX Project_log_project_id_idx on Project_Log (project_id);
CREATE INDEX Project_log_when_idx on Project_Log (dtmTimestamp);
