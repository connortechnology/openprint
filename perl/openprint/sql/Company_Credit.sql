DROP	TABLE IF EXISTS Company_Credit;
CREATE	TABLE Company_Credit (
	company_id	INTEGER NOT NULL, FOREIGN KEY (Company_id) REFERENCES Companies (id),
	supplier_id	INTEGER NOT NULL, FOREIGN KEY (supplier_id) REFERENCES Companies (id),
	dblLimit	NUMERIC(10,2),
	DenyDays	INTEGER,
	WarnDays	INTEGER,
	Downpayment	NUMERIC(10,2),
	Hold		CHAR(1) DEFAULT 'N'
	cod			float,
	PRIMARY KEY (company_id,supplier_id)
);
