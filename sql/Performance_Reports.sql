DROP TABLE IF EXISTS Performance_Reports;
CREATE TABLE Performance_Reports (

    id	SERIAL,
    shift_id	INTEGER NOT NULL, FOREIGN KEY (shift_id) REFERENCES Shifts (id),
    operator_id	INTEGER NOT NULL, FOREIGN KEY (operator_id) REFERENCES Users (index),
    created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted		BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (id)
);

CREATE INDEX performance_reports_idx on Performance_reports (shift_id,operator_id);

