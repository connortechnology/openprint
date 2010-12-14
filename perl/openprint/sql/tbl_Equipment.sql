DROP SEQUENCE Equipment_Index_seq;
CREATE SEQUENCE Equipment_Index_seq;

DROP TABLE tbl_Equipment;

CREATE TABLE tbl_Equipment (
	lngIndex			INT4 NOT NULL DEFAULT nextval('Equipment_Index_seq'),
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
	sorting				integer,
	message				text,
	PRIMARY KEY (lngIndex)
);

CREATE INDEX EquipmentID_Index ON tbl_Equipment (strID);
