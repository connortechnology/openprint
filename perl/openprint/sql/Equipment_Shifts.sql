
DROP TABLE IF EXISTS Equipment_Shifts;
CREATE TABLE Equipment_Shifts (
	id			SERIAL,
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (id),
	starttime_seconds	integer	NOT NULL,
	duration_seconds	integer	NOT NULL,
	name		TEXT	NOT NULL,
	PRIMARY KEY (id)
);
CREATE INDEX Equipment_Shifts_idx on Equipment_Shifts (equipment_id, starttime_seconds );

