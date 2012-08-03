CREATE TABLE Inks (
	id		SERIAL,
	pmsid	TEXT,
	service_id		INTEGER, FOREIGN KEY (service_id) REFERENCES Services (id),
	material_id		INTEGER, FOREIGN KEY (material_id) REFERENCES Materials (id),
	washups			integer,
	strColourName		TEXT,
	PRIMARY KEY (id)
);

