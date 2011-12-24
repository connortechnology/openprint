DROP TABLE IF EXISTS RMA;

CREATE TABLE RMA (
	id		SERIAL,
	company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	project_id	INTEGER, FOREIGN KEY (project_id) REFERENCES Projects (id),
	order_id	INTEGER, FOREIGN KEY (order_id) REFERENCES Orders (id),
	type 			char(1) DEFAULT '' NOT NULL,
	created_on		timestamp with time zone not null default NOW(),
	description		TEXT,
	comments		TEXT,
	RMANumber		TEXT,
	approve 		char(1),
	PRIMARY KEY (id)
);

