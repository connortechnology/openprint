DROP TABLE IF EXISTS Paper_Prices;

CREATE TABLE Paper_Prices (
	id					SERIAL,
	lngListIndex		INTEGER NOT NULL, FOREIGN KEY (lngListIndex) REFERENCES Pricelists (id),
	lngPaperIndex		INTEGER NOT NULL, FOREIGN KEY (lngPaperIndex) REFERENCES Paper (id),
	dtmStart			TIMESTAMP with time zone,
	dtmEnd				TIMESTAMP with time zone,
	lngMin				NUMERIC( 12,4 ),
	lngMax				NUMERIC( 12,4 ),
	strUnits			TEXT,
	dblCost				NUMERIC( 10, 5 ),
	dblMarkup			NUMERIC( 10, 2 ),
	dblPrice			NUMERIC( 10, 5 ),
	ysnDiscountable     CHAR(1) DEFAULT 'Y'
	equipment_id		INTEGER, FOREIGN KEY (equipment_Id) REFERENCES tbl_Equipment (id),
	service				TEXT,
	PRIMARY KEY(id)
);
CREATE Paper_Prices_idx on Paper_Prices (lngpaperindex,lnglistindex);
