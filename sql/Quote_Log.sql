CREATE TABLE Quote_Log (
	id SERIAL NOT NULL,
	quote_id	INTEGER	NOT NULL, FOREIGN KEY(quote_id) REFERENCES Quotes (id),
	company_id	INTEGER, FOREIGN KEY(company_id) REFERENCES Companies (id),
	user_id		INTEGER, FOREIGN KEY(user_id) REFERENCES Users (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	description 	TEXT,
	PRIMARY KEY (id)
);
