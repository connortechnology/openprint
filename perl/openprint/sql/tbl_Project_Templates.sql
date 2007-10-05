DROP	SEQUENCE ProjectTemplate_Id_seq;
CREATE	SEQUENCE ProjectTemplate_Id_seq;

DROP TABLE ProjectTemplate;
CREATE TABLE ProjectTemplate (
	id	INTEGER NOT NULL default nextval('ProjectTemplate_id_seq'),
	ProjectType_id		 INTEGER NOT NULL, FOREIGN KEY (ProjectTYpe_id) REFERENCES Project_Types (lngIndex);
	Type				TEXT NOT NULL,
	Description			TEXT,
	dblFinishedWidth	NUMERIC(10,4),
	dblFinishedHeight	NUMERIC(10,4),
	dblFlatWidth		NUMERIC(10,4),
	dblFlatHeight		NUMERIC(10,4),
	PRIMARY KEY (Id)
);

create index ProjectTemplate_ProjectType_idx on projecttemplate (projecttype_id);


