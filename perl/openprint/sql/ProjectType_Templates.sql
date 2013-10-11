DROP	SEQUENCE IF EXISTS ProjectTemplate_Id_seq;
CREATE	SEQUENCE ProjectTemplate_id_seq;

DROP TABLE IF EXISTS ProjectTemplate;
CREATE TABLE ProjectTemplate (
	id	INTEGER NOT NULL default nextval('ProjectTemplate_id_seq'),
	projecttype_id		 INTEGER NOT NULL, FOREIGN KEY (ProjectTYpe_id) REFERENCES Project_Types (id),
	Type				TEXT NOT NULL,
	name				TEXT,
	Description			TEXT,
	dblFinishedWidth	NUMERIC(10,4),
	dblFinishedHeight	NUMERIC(10,4),
	dblFlatWidth		NUMERIC(10,4),
	dblFlatHeight		NUMERIC(10,4),
	message				TEXT,
	PRIMARY KEY (Id)
);

create index ProjectTemplate_ProjectType_idx on projecttemplate (projecttype_id);


