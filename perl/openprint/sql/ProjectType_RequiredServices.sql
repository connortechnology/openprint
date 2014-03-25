CREATE TABLE ProjectType_RequiredServices (
	projecttype_id	INTEGER NOT NULL, FOREIGN KEY (projecttype_id) REFERENCES Project_Types (id),
	servicetype_id	INTEGER NOT NULL, FOREIGN KEY (servicetype_id) REFERENCES Service_Types (id),
	PRIMARY KEY (projecttype_id, servicetype_id)
);
