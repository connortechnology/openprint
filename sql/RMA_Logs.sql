

CREATE TABLE RMA_Logs (
	rma_id	INTEGER	NOT NULL, FOREIGN KEY(rma_id) REFERENCES RMA(id),
	company_id	INTEGER, FOREIGN KEY(company_id) REFERENCES Companies (id),
	user_id		INTEGER, FOREIGN KEY(user_id) REFERENCES Users (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	description			TEXT,
	PRIMARY KEY (rma_id,created_on)
);
