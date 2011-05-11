DROP TABLE IF EXISTS PerformancePoint_Records;
CREATE TABLE PerformancePoint_Records (
	shift_id	INTEGER, FOREIGN KEY (shift_id) REFERENCES Shifts (id),
	operator_id	INTEGER NOT NULL, FOREIGN KEY (operator_id) REFERENCES Users (Index),
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES PerformancePoint_Types (id),
	quantity	float,
	total		INTEGER,
	PRIMARY KEY (shift_id,operator_id,type_id)
);
