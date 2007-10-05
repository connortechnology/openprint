
DROP TABLE Order_Log;

CREATE TABLE Order_Log (
	order_id	INTeger	NOT NULL, FOREIGN KEY(Order_Id) REFERENCES Orders (index),
	Company_id	INTeger	NOT NULL, FOREIGN KEY(Company_id) REFERENCES Company (index),
	User_id		INTeger	NOT NULL, FOREIGN KEY(User_Id) REFERENCES Users (index),
	dtmwhen		timestamp with time zone NOT NULL default(NOW()),
	Description			TEXT,
	PRIMARY KEY (Order_Id,dtmwhen)
);
