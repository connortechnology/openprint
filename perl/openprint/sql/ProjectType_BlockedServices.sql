CREATE TABLE ProjectType_BlockedServices (
	projecttype_id	INTEGER NOT NULL, FOREIGN KEY (projecttype_id) REFERENCES project_types (id),
	servicetype_id	INTEGER NOT NULL, FOREIGN KEY (servicetype_id) REFERENCES service_types (id),
	PRIMARY KEY (ProjectType_id, servicetype_id)
);
