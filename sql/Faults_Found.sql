CREATE TABLE Faults_Found (
	id	SERIAL,
	fault_id	INTEGER, FOREIGN KEY (fault_id) REFERENCES Faults (id),
	action	TEXT,
	rma_id	INTEGER, FOREIGN KEY (rma_id) REFERENCES RMA (id),
	quantity		INTEGER,
	PRIMARY KEY (id)
);

