
DROP TABLE Quote_Log;

CREATE TABLE Quote_Log (
	quote_id	INTeger	NOT NULL, FOREIGN KEY(quote_Id) REFERENCES tbl_Quotes (index),
	Company_id	INTeger	NOT NULL, FOREIGN KEY(company_id) REFERENCES Company (index),
	User_id		INTeger	NOT NULL, FOREIGN KEY(user_id) REFERENCES Users (index),
	dtmwhen		timestamp with time zone NOT NULL default(NOW()),
	Description			TEXT,
	PRIMARY KEY (quote_Id,dtmwhen)
);
