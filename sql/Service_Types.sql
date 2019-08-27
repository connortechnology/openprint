
CREATE TABLE Service_Types (
	id				SERIAL NOT NULL,
	name			TEXT,
	description		TEXT,
	category_id		INTEGER,FOREIGN KEY (category_id) REFERENCES ServiceType_Categories (id),
	strDetailedURL	TEXT,
	create_visible	CHAR(1) default 'Y',
	view_visible	CHAR(1) default 'Y',
	summary_visible	BOOLEAN NOT NULL default true,
	sorting			INTEGER,
	type			TEXT,
	allow_delete BOOLEAN NOT NULL default true,
	PRIMARY KEY (id)
);

CREATE INDEX service_types_name_idx ON Service_Types (name);



