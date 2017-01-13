DROP TABLE IF EXISTS Performance_Records;
CREATE TABLE Performance_Records (
	docket		INTEGER NOT NULL,
	report_id	INTEGER NOT NULL, FOREIGN KEY (report_id) REFERENCES Performance_Reports (id),
	type_id		INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES Performance_Point_Types (id),
	quantity	FLOAT,
	total		INTEGER,
	PRIMARY KEY (report_id,docket,type_id)
);
