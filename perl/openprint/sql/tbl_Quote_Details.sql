DROP TABLE tbl_Quote_Details;

CREATE TABLE tbl_Quote_Details (
	QuoteIndex		INT4 NOT NULL, FOREIGN KEY (QuoteIndex) REFERENCES tbl_Quotes (Index),
	ProjectIndex	INT4 NOT NULL, FOREIGN KEY (ProjectIndex) REFERENCES Projects (Index),
	strDescription	TEXT,

	intQuantity1	INT4,
	dblMarkup1		NUMERIC(10,2),
	dblPrice1		NUMERIC(20,2),

	intQuantity2	INT4,
	dblMarkup2		NUMERIC(10,2),
	dblPrice2		NUMERIC(20,2),

	intQuantity3	INT4,
	dblMarkup3		NUMERIC(10,2),
	dblPrice3		NUMERIC(20,2)
);


