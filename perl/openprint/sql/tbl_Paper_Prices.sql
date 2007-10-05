DROP TABLE tbl_Paper_Prices;

CREATE TABLE tbl_Paper_Prices (
	lngListIndex		INT4 NOT NULL, FOREIGN KEY (lngListIndex) REFERENCES Pricelists (Index),
	lngPaperIndex		INT4 NOT NULL, FOREIGN KEY (lngPaperIndex) REFERENCES tbl_Paper (lngIndex),
	dtmStart			TIMESTAMP with time zone,
	dtmEnd				TIMESTAMP with time zone,
	lngMin				NUMERIC( 12,4 ),
	lngMax				NUMERIC( 12,4 ),
	strUnits			TEXT,
	dblCost				NUMERIC( 10, 5 ),
	dblMarkup			NUMERIC( 10, 2 ),
	dblPrice			NUMERIC( 10, 5 ),
	ysnDiscountable     CHAR(1) DEFAULT 'Y'

);
