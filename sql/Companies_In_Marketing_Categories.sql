
CREATE TABLE Companies_In_Marketing_Categories (
	category_id	INTEGER NOT NULL, FOREIGN KEY (category_id)  REFERENCES Marketing_Categories (id),
	company_id		INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	PRIMARY KEY (company_id,category_id)
);
