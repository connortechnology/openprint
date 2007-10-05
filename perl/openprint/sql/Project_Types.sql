DROP	SEQUENCE ProjectTypeIndex;
CREATE	SEQUENCE ProjectTypeIndex;

DROP TABLE Project_Types;
CREATE TABLE Project_Types (
	lngIndex		INT4 NOT NULL default nextval('ProjectTypeIndex'),
	strID			TEXT,
	strName			TEXT,
	strDetailedURL	TEXT,
	lngSort			INT4,
	category_id		INTEGER, FOREIGN KEY (category_id) REFERENCES ProjectType_Categories (id),
	PRIMARY KEY (lngIndex)
);


create index ProjectTypesID_index on Project_Types (strID);
