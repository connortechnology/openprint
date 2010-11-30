DROP TABLE IF EXISTS Service_Prices;

CREATE TABLE Service_Prices (
	pricelist_id	INTEGER NOT NULL, FOREIGN KEY (pricelist_id) REFERENCES Pricelists (id),
	service_id		INTEGER NOT NULL, FOREIGN KEY (service_id) REFERENCES Services (id),
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (id),
	supplier_id		INTEGER, FOREIGN KEY (supplier_id) REFERENCES Companies (id),
	dtmStart		TIMESTAMP,
	dtmEnd			TIMESTAMP,
	min			float,
	Max			float,
	Units			TEXT,
	Cost			float,
	Markup			float,
	Price			float,
	Discountable	CHAR(1) DEFAULT 'Y'
);
create index service_price_index on service_prices (pricelist_id, service_id,equipment_id);
