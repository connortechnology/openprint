DROP TABLE IF EXISTS RMA;

CREATE TABLE RMA (
	id		SERIAL,
	company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	project_id	INTEGER, FOREIGN KEY (project_id) REFERENCES Projects (id),
	order_id	INTEGER, FOREIGN KEY (order_id) REFERENCES Orders (id),
	type_id			INTEGER, FOREIGN KEY (type_id) REFERENCES RMA_Types (id),
	status_id		INTEGER, FOREIGN KEY (status_id) REFERENCES RMA_Statuses (id),
	created_on		timestamp with time zone not null default NOW(),
	description		TEXT,
	comments		TEXT,
	RMANumber		TEXT,
	approved 		BOOLEAN NOT NULL DEFAULT False,
	PRIMARY KEY (id)
);

