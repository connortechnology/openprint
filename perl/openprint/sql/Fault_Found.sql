CREATE TABLE Fault_Found (
	id	SERIAL,
	fault_id	INTEGER, FOREIGN KEY (fault_id) REFERENCES Faults (id),
	action	TEXT,
	workorder_id	INTEGER, FOREIGN KEY (workorder_id) REFERENCES WorkOrders (id),
	quantity		INTEGER,
	PRIMARY KEY (id)
);

