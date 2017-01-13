DROP TABLE tbl_Prices;

CREATE TABLE tbl_Prices(
	lngID			INT4 NOT NULL, /* priceslit ID or cust_id */
	lngProductIndex	INT4 NOT NULL,
	dtmStart		TIMESTAMP,
	dtmEnd			TIMESTAMP,
	lngMin			INT4,
	lngMax			INT4,
	dblSetupCost	NUMERIC( 10, 5 ),
	dblSetupMarkup	NUMERIC( 10, 2 ),
	dblSetupPrice	NUMERIC( 10, 5 ),
	dblUnitCost		NUMERIC( 10, 5 ),
	dblUnitMarkup	NUMERIC( 10, 2 ),
	dblUnitPrice	NUMERIC( 10, 5 )
);
