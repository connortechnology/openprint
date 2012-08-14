
DROP TABLE IF EXISTS Locations;
DROP TABLE IF EXISTS Location_Types;

CREATE TABLE Location_Types (
	id SERIAL,
	name	TEXT,
	PRIMARY KEY (id)
);

CREATE TABLE Locations (
	id SERIAL NOT NULL,
	parent_id	INTEGER, FOREIGN KEY (parent_id) REFERENCES Locations (id),
	name	TEXT,UNIQUE(name),
	short	TEXT,
	coordinates	TEXT,
	type_id		INTEGER, FOREIGN KEY (type_id) REFERENCES Location_types (id),
	created_on	timestamp with time zone not null default NOW(),
	updated_on	timestamp with time zone not null default NOW(),
	created_by	INTEGER, FOREIGN KEY (created_by) REFERENCES Users (id),
	postalcode	text,
	address		text,
	latitude	float,
	longitude	float,
	url			text,
	asset_id				INTEGER,
	description	text,
	deleted		BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (id)
);

