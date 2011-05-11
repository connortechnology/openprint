DROP TABLE IF EXISTS PerformancePoints;
CREATE TABLE PerformancePoints (
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES PerformancePoint_Types (id),
	units	TEXT,
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (lngindex),
	value	integer,
	max_value	INTEGER,
	PRIMARY KEY (equipment_id,type_id)
);
