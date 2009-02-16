DROP TABLE IF EXISTS companies_in_marketing_categories;
CREATE TABLE companies_in_marketing_categories (
		company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
		category_id	INTEGER NOT NULL, FOREIGN KEY (category_id) REFERENCES Marketing_Categories (Id)
);


