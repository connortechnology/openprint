DROP	TABLE IF EXISTS Company_Credit;
CREATE	TABLE Company_Credit (
	company_id	INTEGER NOT NULL, FOREIGN KEY (Company_id) REFERENCES Companies (id),
	supplier_id	INTEGER NOT NULL, FOREIGN KEY (supplier_id) REFERENCES Companies (id),
	dblLimit	NUMERIC(10,2),
	DenyDays	INTEGER,
	WarnDays	INTEGER,
	downpayment	NUMERIC(10,2),
	hold		CHAR(1) DEFAULT 'N',
	cod			float,
	late_payment_amount	float,
	late_payment_units	text,
	early_payment_amount	float,
	early_payment_units	text,
	early_payment_days	smallint,
	terms integer,
	PRIMARY KEY (company_id,supplier_id)
);
