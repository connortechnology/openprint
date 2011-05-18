DROP TABLE IF EXISTS Performance_Records;
CREATE TABLE Performance_Records (

    id	SERIAL,
    shift_id	INTEGER NOT NULL, FOREIGN KEY (shift_id) REFERENCES Shifts (id),
    operator_id	INTEGER NOT NULL, FOREIGN KEY (operator_id) REFERENCES Users (index),
    created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    updated_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
    deleted		BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (id)
);

CREATE INDEX performance_records_idx on Performance_records (shift_id,operator_id);

