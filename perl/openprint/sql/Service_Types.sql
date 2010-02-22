
DROP TABLE IF EXISTS Service_Types;
CREATE TABLE Service_Types (
	id				SERIAL NOT NULL,
	Name			TEXT,
	description		TEXT,
	category_id		INTEGER,FOREIGN KEY (category_id) REFERENCES ServiceType_Categories (id),
	strDetailedURL	TEXT,
	create_visible	CHAR(1) default 'Y',
	view_visible	CHAR(1) default 'Y',
	sorting			INTEGER,
	type			TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX Service_Types_name_Idx ON Service_Types (name);


