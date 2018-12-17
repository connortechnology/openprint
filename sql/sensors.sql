DROP TABLE IF EXISTS sensors CASCADE;

CREATE TABLE sensors (
	id	serial,
	name	VARCHAR(255),
	description	VARCHAR(255),
	url			VARCHAR(255),
	username	VARCHAR(255),
	password	VARCHAR(255),
	created		TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	modified	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	type_id		INT NOT NULL,
deleted	BOOLEAN NOT NULL DEFAULT False,
	FOREIGN KEY (type_id) REFERENCES sensor_types(id),
	primary key (id)
);
