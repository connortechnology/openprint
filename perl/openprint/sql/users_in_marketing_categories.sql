DROP TABLE IF EXISTS users_in_marketing_categories;
CREATE TABLE users_in_marketing_categories (
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	category_id	INTEGER NOT NULL, FOREIGN KEY (category_id) REFERENCES marketing_categories (id)
);

