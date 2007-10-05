DROP TABLE tbl_Material_Prices;

CREATE TABLE tbl_Material_Prices (
	lngListIndex		INT4 NOT NULL, FOREIGN KEY (lngListIndex) REFERENCES PriceLists (Index),/* priceslit ID or cust_id */
	lngMaterialIndex	INT4 NOT NULL, FOREIGN KEY (lngMaterialIndex) REFERENCES tbl_Materials (lngIndex),
	lngEquipmentIndex	INT4, FOREIGN KEY (lngEquipmentIndex) REFERENCES tbl_Equipment (lngIndex),
	dtmStart			TIMESTAMP with time zone,
	dtmEnd				TIMESTAMP with time zone,
	lngMin				NUMERIC(10,4),
	lngMax				NUMERIC(10,4),
	strUnits            TEXT,
	dblCost				NUMERIC( 10, 5 ),
	dblMarkup			NUMERIC( 10, 2 ),
	dblPrice			NUMERIC( 10, 5 ),
	ysnDiscountable     CHAR(1) DEFAULT 'Y'

);

CREATE INDEX material_price_index on tbl_Material_Prices ( lngListIndex, lngMaterialIndex, lngEquipmentIndex );
