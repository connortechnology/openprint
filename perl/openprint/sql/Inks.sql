
DROP TABLE IF EXISTS Inks;
DROP SEQUENCE IF EXISTS Inks_id_seq;

CREATE  SEQUENCE Inks_id_seq;

CREATE TABLE Inks (
	id		INTEGER NOT NULL default nextval('inks_id_seq'),
	pmsid	TEXT,
	service_id		INTEGER, FOREIGN KEY (service_id) REFERENCES Services (id),
	material_id		INTEGER, FOREIGN KEY (material_id) REFERENCES Materials (id),
	washups			integer,
	strColourName		TEXT,
	PRIMARY KEY (id)
);

