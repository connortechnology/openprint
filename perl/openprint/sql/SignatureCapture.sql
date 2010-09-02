CREATE TABLE SignatureCapture (
	id	SERIAL,
	image_data	bytea NOT NULL,
	project_id	INTEGER NOT NULL, FOREIGN KEY (project_id) REFERENCES Projects (id),
	service_id	INTEGER NOT NULL, 
/*FOREIGN KEY (service_id) REFERENCES tbl_Project_Contents(lngserviceindex), */
	deleted		BOOLEAN NOT NULL default false,
	PRIMARY KEY (id)
);
