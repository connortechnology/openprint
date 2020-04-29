CREATE TABLE Test_Results (
	id SERIAL,
	employee_id INTEGER NOT NULL, FOREIGN KEY (employee_id) REFERENCES USers (id),
	technician_id INTEGER NOT NULL, FOREIGN KEY (technician_id) REFERENCES USers (id),
	rma_id		INTEGER NOT NULL, FOREIGN KEY (rma_id) REFERENCES RMA (id),
	rdate		TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	tested_on		TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	result_id		INTEGER NOT NULL, FOREIGN KEY (result_id) REFERENCES Test_Result_Results (id),
	remarks		TEXT,
	problem_level	TEXT,
	cost		float,
	test_id		INTEGER NOT NULL, FOREIGN KEY (test_id) REFERENCES Tests (id),
	
	PRIMARY KEY (id)
);
