
DROP TABLE IF EXISTS Equipment_Shifts;
CREATE TABLE Equipment_Shifts (
	id			SERIAL,
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (id),
	starttime	time	NOT NULL,
	duration	interval	NOT NULL,
	name		TEXT	NOT NULL,
	PRIMARY KEY (id)
);
CREATE INDEX Equipment_Shifts_idx on Equipment_Shifts (equipment_id, starttime );

