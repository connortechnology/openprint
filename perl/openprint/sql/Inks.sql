CREATE TABLE Inks (
	id		SERIAL,
	pmsid	TEXT,
	service_id		INTEGER, FOREIGN KEY (service_id) REFERENCES Services (id),
	material_id		INTEGER, FOREIGN KEY (material_id) REFERENCES Materials (id),
	washups			integer,
	name		TEXT,
	mix			BOOLEAN NOT NULL default false,
	grades		INTEGER[],
	PRIMARY KEY (id)
);

