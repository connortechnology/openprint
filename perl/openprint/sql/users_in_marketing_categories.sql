DROP TABLE users_in_marketing_categories;
CREATE TABLE users_in_marketing_categories (
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (Index),
	category_id	INTEGER NOT NULL, FOREIGN KEY (category_id) REFERENCES marketing_category (id)
);

