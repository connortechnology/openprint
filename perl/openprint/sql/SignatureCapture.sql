CREATE TABLE SignatureCapture (
	id	SERIAL,
	image_data	bytea NOT NULL,
	project_id	INTEGER NOT NULL, FOREIGN KEY (project_id) REFERENCES Projects (id),
	service_id	INTEGER NOT NULL, 
	type		CHAR(3),
/*FOREIGN KEY (service_id) REFERENCES tbl_Project_Contents(lngserviceindex), */
	deleted		BOOLEAN NOT NULL default false,
	created_on	timestamp with time zone not null default now(),
	PRIMARY KEY (id)
);

create index signaturecapture_project_service_idx ON signaturecapture (project_id,service_id);
