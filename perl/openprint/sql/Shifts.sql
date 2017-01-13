

/* Shifts implements each actual shift.  It stores the operator, and theoretically could allow shifts to move around on the fly. */
DROP TABLE IF EXISTS Shifts;
CREATE TABLE Shifts (
	id				SERIAL,
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (id),
	starttime		timestamp with time zone NOT NULL,
	endtime			timestamp with time zone NOT NULL,
	operator_id		INTEGER, FOREIGN KEY (operator_id) REFERENCES Users (id),
	shift_id		INTEGER NOT NULL, FOREIGN KEY (shift_id) REFERENCES Equipment_shifts (id),
	PRIMARY KEY (id)
);

CREATE INDEX Shifts_idx on Shifts (equipment_id, starttime );

