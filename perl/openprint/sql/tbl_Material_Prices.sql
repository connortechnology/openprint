DROP TABLE tbl_Material_Prices;

CREATE TABLE tbl_Material_Prices (
	lngListIndex		INTEGER NOT NULL, FOREIGN KEY (lngListIndex) REFERENCES PriceLists (id),/* priceslit ID or cust_id */
	lngMaterialIndex	INTEGER NOT NULL, FOREIGN KEY (lngMaterialIndex) REFERENCES Materials (id),
	lngEquipmentIndex	INTEGER, FOREIGN KEY (lngEquipmentIndex) REFERENCES tbl_Equipment (lngindex),
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
