CREATE TABLE sensor_readings (
	id	serial,
	taken		TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW() NOT NULL,
	sensor_input_id	INT NOT NULL,
	value		float NOT NULL,
	FOREIGN KEY (sensor_input_id) REFERENCES sensor_inputs(id),
	primary key (id)
);
