DROP TABLE tbl_Quote_Details;

CREATE TABLE tbl_Quote_Details (
	QuoteIndex		INTEGER NOT NULL, FOREIGN KEY (QuoteIndex) REFERENCES tbl_Quotes (Index),
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


