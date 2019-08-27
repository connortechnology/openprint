
DROP TABLE IF EXISTS Location_Types;

CREATE TABLE Location_Types (
	id SERIAL,
	name	TEXT,
	PRIMARY KEY (id)
);

INSERT INTO Location_Types (name) values ('country');
INSERT INTO Location_Types (name) values ('state');
INSERT INTO Location_Types (name) values ('city');

