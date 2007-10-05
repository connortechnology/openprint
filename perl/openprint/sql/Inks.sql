
DROP TABLE Inks;
DROP SEQUENCE Inks_id_seq;

CREATE  SEQUENCE Inks_id_seq;

CREATE TABLE tbl_Ink_Colours (
	id		INTEGER NOT NULL default('inks_id_seq'),
	pmsid	TEXT,
	service_id		INTEGER, FOREIGN KEY (service_id) REFERENCES tbl_Services (lngIndex),
	material_id		INTEGER, FOREIGN KEY (material_id) REFERENCES tbl_Materials (lngIndex),
	washups			integer,
	strColourName		TEXT,
	PRIMARY KEY (id)
);

