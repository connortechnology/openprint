
CREATE TABLE Sales_Logs (
	id SERIAL,
	salesrep_id	INTEGER, FOREIGN KEY (salesrep_id) REFERENCES Users (id),
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES Users (id),
	company_id	INTEGER, FOREIGN KEY (company_id) REFERENCES Companies (id),
	date_time	timestamp with time zone NOT NULL,
	notes		TEXT,
	PRIMARY KEY (id)
);


create index sales_logs_salesrep_company_idx on sales_logs (salesrep_id,company_id);
