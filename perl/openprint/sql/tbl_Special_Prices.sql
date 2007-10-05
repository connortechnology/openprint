DROP TABLE tbl_Special_Prices;

CREATE TABLE tbl_Special_Prices(
	lngID	INT4 NOT NULL, /* priceslit ID or cust_id */
	lngProductIndex	INT4 NOT NULL,
	dtmStart	TIMESTAMP,
	dtmEnd		TIMESTAMP,
	lngMin		INT4,
	lngMax		INT4,
	dblMarkup	NUMERIC(10,2),
	dblPrice	NUMERIC(10,2)
);
