CREATE TABLE Barcode_Log (
	project_id	INTEGER NOT NULL, FOREIGN KEY (project_id) REFERENCES tbl_Projects (Index),
	DocketNumber	INTEGER NOT NULL,
	dtmTimestamp	timestamp with time zone NOT NULL,
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (Index),
	operator_id	INTEGER NOT NULL, FOREIGN KEY (operator_id) REFERENCES Users (Index),
	Description	TEXT
);

CREATE INDEX BarcodeLog_When_idx ON Barcode_Log (dtmtimestamp);
