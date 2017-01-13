DROP TABLE IF EXISTS SRED_Projects;
CREATE TABLE SRED_Projects (
	id SERIAL,
	name TEXT NOT NULL,
	description	TEXT,
	created_by	INTEGER, FOREIGN KEY (created_by) REFERENCES Users (id),
	created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	PRIMARY KEY (id)
);
CREATE INDEX sred_projects_name_idx on SRED_Projects (name);

