DROP	TABLE Company_Credit;
CREATE	TABLE Company_Credit (
	Company_id	INTEGER NOT NULL, FOREIGN KEY (Company_id) REFERENCES Companies (id),
	dblLimit		NUMERIC(10,2),
	DenyDays	INTEGER,
	WarnDays	INTEGER,
	Downpayment      NUMERIC(10,2),
	Hold		CHAR(1) DEFAULT 'N'
);
