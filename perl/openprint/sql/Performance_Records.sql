DROP TABLE IF EXISTS Performance_Records;
CREATE TABLE Performance_Records (
/* 
	shift_id	INTEGER, FOREIGN KEY (shift_id) REFERENCES Shifts (id),
	operator_id	INTEGER NOT NULL, FOREIGN KEY (operator_id) REFERENCES Users (Index),
*/
	docket		INTEGER NOT NULL,
	report_id	INTEGER NOT NULL, FOREIGN KEY (report_id) REFERENCES Performance_Reports (id),
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES PerformancePoint_Types (id),
	quantity	float,
	total		INTEGER,
	PRIMARY KEY (report_id,docket,type_id)
);
