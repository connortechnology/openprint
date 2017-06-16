DROP SEQUENCE IF EXISTS Equipment_Index_seq;
CREATE SEQUENCE Equipment_Index_seq;

DROP TABLE IF EXISTS tbl_Equipment;

CREATE TABLE tbl_Equipment (
	id			INTEGER NOT NULL DEFAULT nextval('Equipment_Index_seq'),
	strID				TEXT,
	strName				TEXT,
	strDescription		TEXT,
	strCategory			TEXT,
	category_id			INTEGER[],
	servicetype_id		INTEGER[],
	strSupplier			TEXT,
	image				TEXT, /* Relative to /images/equipment */
	useinscheduling		boolean,
	useinestimating		boolean,
	jmf_enabled			boolean,
	instantgate_enabled	boolean,
	cost_center				TEXT, 
    cip3_in				TEXT,
    cip3_out			TEXT,
    cip3_hold			boolean,
    cip3_merge			boolean,
    cip3_monitor		boolean,
	jdf_id				TEXT,
	jdf_name			TEXT,
	location_id			INTEGER, FOREIGN KEY (location_id) REFERENCES Locations(id),
	smartscheduling		BOOLEAN,
	sorting				integer,
	message				text,
	deleted				BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (id)
);

CREATE INDEX EquipmentID_idx ON tbl_Equipment (strID);
