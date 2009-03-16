DROP TABLE IF EXISTS Locations;
CREATE TABLE Locations (
	id SERIAL NOT NULL,
	name	TEXT,UNIQUE(name),
	coordinates	TEXT,
	created_on	timestamp with time zone not null default NOW(),
	updated_on	timestamp with time zone not null default NOW(),
	PRIMARY KEY (id)
);

