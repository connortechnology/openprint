DROP	TABLE Company_Credit;
CREATE	TABLE Company_Credit (
	Company_id	INTEGER NOT NULL, FOREIGN KEY (Company_id) REFERENCES Companies (id),
	dblLimit		NUMERIC(10,2),
	DenyDays	INTEGER NOT NULL,
	WarnDays	INTEGER NOT NULL,
	Downpayment      NUMERIC(10,2),
	Hold		CHAR(1) DEFAULT 'N'
);
