CREATE TABLE Service_Prices (
	id	SERIAL,
	pricelist_id	INTEGER NOT NULL, FOREIGN KEY (pricelist_id) REFERENCES Pricelists (id),
	service_id		INTEGER NOT NULL, FOREIGN KEY (service_id) REFERENCES Services (id),
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (id),
	supplier_id		INTEGER, FOREIGN KEY (supplier_id) REFERENCES Companies (id),
	min			float,
	max			float,
	units			TEXT,
	cost			float,
	markup			float,
	price			float,
	discountable	CHAR(1) DEFAULT 'Y',
	period_start	TIMESTAMP WITH TIME ZONE,
	period_end		TIMESTAMP WITH TIME ZONE,
	PRIMARY KEY (id)
);
create index service_price_index on service_prices (pricelist_id, service_id,equipment_id);
