DROP TABLE IF EXISTS Todos;
CREATE TABLE Todos (
	id SERIAL,
	owner_id	INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (id),
	title		TEXT,
	description	TEXT,
	duedate		date,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	project_id	INTEGER, FOREIGN KEY (project_id) REFERENCES tbl_Projects (id),
	completed	BOOLEAN NOT NULL default false,
	PRIMARY KEY (id)
);
