DROP TABLE IF EXISTS Trade_References;

CREATE TABLE Trade_References (
	Id	INTEGER NOT NULL,
	Company_id INTEGER NOT NULL,FOREIGN KEY (company_id) REFERENCES Companies (id),
	CompanyName TEXT,
	Contact		TEXT,
	Phone		TEXT,
	Ext			TEXT,
	Fax			TEXT,
	Email		TEXT,
	CreditLimit INT4,
	PRIMARY KEY (company_id, id )
);

