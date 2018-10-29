CREATE TABLE Shipping_Rates (
	id	SERIAL,
	servicetype_id	INTEGER NOT NULL, FOREIGN KEY (servicetype_id) REFERENCES ServiceTypes (id),
	from_id	INTEGER NOT NULL, FOREIGN KEY (from_id) REFERENCES Locations(id),
	to_id	INTEGER NOT NULL, FOREIGN KEY (to_id) REFERENCES Locations(id),
	base_rate	NUMERIC(10,2),
	additional_rate	NUMERIC(10,2),
	PRIMARY KEY (id)
);

CREATE INDEX Shipping_Rates_idx on Shipping_Rates (from_id,to_id);
