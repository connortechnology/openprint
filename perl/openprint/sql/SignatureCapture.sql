CREATE TABLE SignatureCapture (
	id	SERIAL,
	image_data	bytea NOT NULL,
	project_id	INTEGER NOT NULL, FOREIGN KEY (project_id) REFERENCES tbl_Projects (index),
	service_id	INTEGER NOT NULL, 
/*FOREIGN KEY (service_id) REFERENCES tbl_Project_Contents(lngserviceindex), */
	deleted		BOOLEAN NOT NULL default false,
	created_on	timestamp with time zone not null default now(),
	PRIMARY KEY (id)
);
