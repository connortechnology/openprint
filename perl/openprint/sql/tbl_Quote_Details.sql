DROP TABLE IF EXISTS tbl_Quote_Details;

CREATE TABLE tbl_Quote_Details (
	quote_id		INTEGER NOT NULL, FOREIGN KEY (quote_id) REFERENCES Quotes (id),
	ProjectIndex	INTEGER NOT NULL, FOREIGN KEY (ProjectIndex) REFERENCES Projects (id),
	strDescription	TEXT,

	intQuantity1	INTEGER,
	dblMarkup1		NUMERIC(10,2),
	dblPrice1		NUMERIC(20,2),

	intQuantity2	INTEGER,
	dblMarkup2		NUMERIC(10,2),
	dblPrice2		NUMERIC(20,2),

	intQuantity3	INTEGER,
	dblMarkup3		NUMERIC(10,2),
	dblPrice3		NUMERIC(20,2)
);


