CREATE TABLE Order_Notifications (
	order_id	INTEGER, FOREIGN KEY (order_id) REFERENCES Orders (id),
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES Users (id),
	PRIMARY KEY (order_id,user_id)
);
