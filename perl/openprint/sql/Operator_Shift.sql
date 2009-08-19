DROP TABLE IF EXISTS Operator_Shifts;

CREATE TABLE Operator_Shifts (
	id				SERIAL,
	shift_id		INTEGER NOT NULL, FOREIGN KEY (shift_id) REFERENCES Equipment_Shifts (id),
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (lngindex),
	operator_id		INTEGER NOT NULL, FOREIGN KEY (operator_id) REFERENCES Users (Index),
	starttime		timestamp with time zone NOT NULL,
	PRIMARY KEY (id)
);

CREATE INDEX Operator_Shift_idx on Operator_Shifts (equipment_id,operator_id);
