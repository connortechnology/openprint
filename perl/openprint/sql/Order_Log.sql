
CREATE TABLE Order_Log (
	id			SERIAL,
	order_id	INTeger	NOT NULL, FOREIGN KEY(Order_Id) REFERENCES Orders (id),
	Company_id	INTeger	NOT NULL, FOREIGN KEY(Company_id) REFERENCES Companies (id),
	User_id		INTeger	NOT NULL, FOREIGN KEY(User_Id) REFERENCES Users (id),
	dtmwhen		timestamp with time zone NOT NULL default(NOW()),
	Description			TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX order_log_order_id_idx ON order_log (order_id,dtmwhen);
