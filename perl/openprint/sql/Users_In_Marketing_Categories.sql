
CREATE TABLE Users_In_Marketing_Categories (
	category_id	INTEGER NOT NULL, FOREIGN KEY (category_id)  REFERENCES Marketing_Categories (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	PRIMARY KEY (user_id,category_id)
);
