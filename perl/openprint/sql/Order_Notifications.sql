CREATE TABLE Order_Notifications (
	order_id	INTEGER, FOREIGN KEY (order_id) REFERENCES Orders (index),
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES User (index),
	PRIMARY KEY (order_id,user_id)
);
