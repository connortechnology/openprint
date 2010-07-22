
DROP TABLE IF EXISTS project_files;
CREATE TABLE project_files ( 
	id			SERIAL,
	project_id	INTEGER NOT NULL, FOREIGN KEY(project_id) REFERENCES Projects (id),
	filename	TEXT NOT NULL,
	description	TEXT NOT NULL,
	upload_id	INTEGER, FOREIGN KEY(upload_id) REFERENCES Uploads (id),
	PRIMARY KEY (id)
);

CREATE INDEX project_files_project_id_idx on project_files (project_id);

