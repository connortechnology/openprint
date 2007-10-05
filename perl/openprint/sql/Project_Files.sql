DROP TABLE project_files;
CREATE TABLE project_files ( 
	project_id	INTEGER NOT NULL, FOREIGN KEY(project_id) REFERENCES tbl_Projects (Index),
	filename	TEXT NOT NULL,
	description	TEXT NOT NULL
);
