DROP TABLE IF EXISTS SRED_Contents;
CREATE TABLE SRED_Contents (
	id			SERIAL,
	project_id	INTEGER, FOREIGN KEY (project_id) REFERENCES SRED_Projects (id),
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES Users (id),
	docket		INTEGER,
	description	TEXT,
	notes	TEXT,
	starting	TIMESTAMP WITH TIME ZONE,
	ending		TIMESTAMP WITH TIME ZONE,
	created_on		TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on		TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	deleted			BOOLEAN NOT NULL default false,
	all_day_event	BOOLEAN,
	unknown_time	BOOLEAN,
	cost			float,
	value			float,
	quantity		float,	
	quantity_units	text,
	type_id			INTEGER, FOREIGN KEY (type_id) REFERENCES SRED_COntent_Types (id),
	created_by		INTEGER,FOREIGN KEY (created_by)  REFERENCES Users (id),
	PRIMARY KEY (id)
);

