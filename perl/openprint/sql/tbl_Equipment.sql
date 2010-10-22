DROP SEQUENCE IF EXISTS Equipment_Index_seq;
CREATE SEQUENCE Equipment_Index_seq;

DROP TABLE IF EXISTS tbl_Equipment;

CREATE TABLE tbl_Equipment (
	lngIndex			INTEGER NOT NULL DEFAULT nextval('Equipment_Index_seq'),
	strID				TEXT,
	strName				TEXT,
	strDescription		TEXT,
	strCategory			TEXT,
	strSupplier			TEXT,
	image				TEXT, /* Relative to /images/equipment */
	useinscheduling		boolean,
	useinestimation		boolean,
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
	PRIMARY KEY (lngIndex)
);

CREATE INDEX EquipmentID_Index ON tbl_Equipment (strID);
