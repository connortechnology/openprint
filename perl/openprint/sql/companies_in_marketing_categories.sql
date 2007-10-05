DROP TABLE companies_in_marketing_categories;
CREATE TABLE companies_in_marketing_categories (
		Company_ID	INTEGER NOT NULL, FOREIGN KEY (Company_ID) REFERENCES Company (Index),
		Category_ID	INTEGER NOT NULL, FOREIGN KEY (Category_ID) REFERENCES Marketing_Category (Id)
);


