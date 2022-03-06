DROP TABLE IF EXISTS sensor_types CASCADE;

CREATE TABLE sensor_types (
	id	serial,
	name	VARCHAR(255),
	PRIMARY KEY (id)
);

INSERT INTO sensor_types (name) values ('LM');
INSERT INTO sensor_types (name) values ('WatchDog');

