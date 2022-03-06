CREATE TABLE sensor_inputs (
	id		serial,
	sensor_id	INT NOT NULL,
	name	text,
	label	text,
	min		float,
	max		float,
	FOREIGN KEY (sensor_id) REFERENCES sensors(id),
	PRIMARY KEY(id)
);
