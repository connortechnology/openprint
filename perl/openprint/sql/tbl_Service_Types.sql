DROP	SEQUENCE ServiceTypeIndex;
CREATE	SEQUENCE ServiceTypeIndex;

DROP TABLE tbl_Service_Types;
CREATE TABLE tbl_Service_Types (
	lngIndex		INT4 NOT NULL default nextval('ServiceTypeIndex'),
	strID			TEXT,
	strName			TEXT,
	strCategory		TEXT,
	strDetailedURL	TEXT,
	strBasicURL		TEXT,
	strTemplateURL	TEXT,
	strEmployeeURL	TEXT,
	ysnCreateVisible	CHAR(1) default 'Y',
	ysnViewVisible	CHAR(1) default 'Y',
	lngSort			INT4,
	PRIMARY KEY (lngIndex)
);

CREATE INDEX ServiceTypeID_Index ON tbl_Service_Types (strID);


