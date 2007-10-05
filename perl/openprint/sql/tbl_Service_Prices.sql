DROP TABLE tbl_Service_Prices;

CREATE TABLE tbl_Service_Prices (
	lngListIndex		INT4 NOT NULL, FOREIGN KEY (lngListIndex) REFERENCES Pricelists (Index),
	lngServiceIndex		INT4 NOT NULL, FOREIGN KEY (lngServiceIndex) REFERENCES tbl_Services (lngIndex),
	lngEquipmentIndex	INT4 NOT NULL, FOREIGN KEY (lngEquipmentIndex) REFERENCES tbl_Equipment (lngIndex),
	dtmStart			TIMESTAMP,
	dtmEnd				TIMESTAMP,
	lngMin				NUMERIC( 12,4 ),
	lngMax				NUMERIC( 12,4 ),
	strUnits			TEXT,
	dblCost				NUMERIC( 10, 5 ),
	dblMarkup			NUMERIC( 10, 2 ),
	dblPrice			NUMERIC( 10, 5 ),
	ysnDiscountable		CHAR(1) DEFAULT 'Y'
);
create index service_price_index on tbl_service_prices (lnglistindex, lngserviceindex,lngequipmentindex);
