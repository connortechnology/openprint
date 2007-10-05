DROP TABLE ProjectType_RequiredServices;
CREATE TABLE ProjectType_RequiredServices (
	ProjectType_id	INTEGER NOT NULL, FOREIGN KEY (ProjectType_id) REFERENCES Project_Types (lngIndex),
	ServiceType_id	INTEGER NOT NULL, FOREIGN KEY (ServiceType_id) REFERENCES tbl_Service_Types (lngIndex),
	PRIMARY KEY (ProjectType_id, ServiceType_id)
);
