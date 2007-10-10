DROP SEQUENCE project_files_id_seq;
CREATE SEQUENCE project_files_id_seq;

DROP TABLE project_files;
CREATE TABLE project_files ( 
	id			INTEGER NOT NULL nextval('project_files_id_seq'),
	project_id	INTEGER NOT NULL, FOREIGN KEY(project_id) REFERENCES tbl_Projects (Index),
	filename	TEXT NOT NULL,
	description	TEXT NOT NULL
	upload_id	INTEGER, FOREIGN KEY(upload_id) REFERENCES Uploads (id),
	PRIMARY KEY (id)
);

CREATE INDEX project_files_project_id_idx on project_files (project_id);

