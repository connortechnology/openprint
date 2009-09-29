DROP TABLE IF EXISTS usergroups;
CREATE TABLE usergroups (
	id	SERIAL NOT NULL,
	name	TEXT,
	PRIMARY KEY (id)
);
