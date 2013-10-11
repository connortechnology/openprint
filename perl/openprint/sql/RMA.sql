DROP TABLE IF EXISTS RMA;

CREATE TABLE RMA (
	id		SERIAL,
	company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	project_id	INTEGER, FOREIGN KEY (project_id) REFERENCES Projects (id),
	order_id	INTEGER, FOREIGN KEY (order_id) REFERENCES Orders (id),
	type_id			INTEGER, FOREIGN KEY (type_id) REFERENCES RMA_Types (id),
	status_id		INTEGER, FOREIGN KEY (status_id) REFERENCES RMA_Statuses (id),
	priority_id		INTEGER, FOREIGN KEY (priority_id) REFERENCES RMA_Priorities (id),
	created_on		timestamp with time zone not null default NOW(),
	updated_on		timestamp with time zone not null default NOW(),
	received_on		TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	description		TEXT,
	comments		TEXT,
	RMANumber		TEXT,
	po_id			INTEGER, FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
	priority		INTEGER,
	warranty		text,
	estimate_required	BOOLEAN,
	approved 		BOOLEAN NOT NULL DEFAULT False,
	tester_id		INTEGER, FOREIGN KEY (tester_id) REFERENCES Users (id),
	accessories		TEXT,
	product_id		INTEGER, FOREIGN KEY (product_id) REFERENCES Products (id),
	PRIMARY KEY (id)
);

