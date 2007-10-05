DROP TABLE tbl_Schedule;

CREATE TABLE tbl_Schedule (
	lngEquipmentIndex	INT4 NOT NULL,
	lngProjectIndex		INT4 NOT NULL,
	dtmEstimatedStartTime	TIMESTAMP,
	dtmEstimatedFinishTime	TIMESTAMP
);
