DROP TABLE IF EXISTS Quote_Log;

CREATE TABLE Quote_Log (
	id SERIAL NOT NULL,
	quote_id	INTeger	NOT NULL, FOREIGN KEY(quote_Id) REFERENCES tbl_Quotes (index),
	company_id	INTeger	NOT NULL, FOREIGN KEY(company_id) REFERENCES Companies (id),
	User_id		INTeger	NOT NULL, FOREIGN KEY(user_id) REFERENCES Users (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	description 	TEXT,
	PRIMARY KEY (id)
);
