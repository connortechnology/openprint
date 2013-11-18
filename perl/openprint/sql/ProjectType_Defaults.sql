CREATE TABLE ProjectType_Defaults (
		id	SERIAL,
		projecttype_id     INTEGER, FOREIGN KEY (projecttype_id) REFERENCES Project_Types (id),
		name            TEXT,
		value         TEXT
		);

