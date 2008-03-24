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
	cost_center			TEXT, 
	jdf_name			TEXT,
	PRIMARY KEY (lngIndex)
);

CREATE INDEX EquipmentID_Index ON tbl_Equipment (strID);
