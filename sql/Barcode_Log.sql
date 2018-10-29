CREATE TABLE Barcode_Log (
	project_id	INTEGER NOT NULL, FOREIGN KEY (project_id) REFERENCES Projects (id),
	DocketNumber	INTEGER NOT NULL,
	dtmTimestamp	timestamp with time zone NOT NULL,
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (Id),
	operator_id	INTEGER NOT NULL, FOREIGN KEY (operator_id) REFERENCES Users (Id),
	Description	TEXT
);

CREATE INDEX BarcodeLog_When_idx ON Barcode_Log (dtmtimestamp);
