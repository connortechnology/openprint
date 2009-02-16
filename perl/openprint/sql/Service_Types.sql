
DROP TABLE IF EXISTS Service_Types;
CREATE TABLE Service_Types (
	id				SERIAL NOT NULL,
	Name			TEXT,
	description		TEXT,
	Category		TEXT,
	strDetailedURL	TEXT,
	Create_Visible	CHAR(1) default 'Y',
	View_Visible	CHAR(1) default 'Y',
	Sorting			INT4,
	type			TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX Service_Types_name_Idx ON Service_Types (name);


