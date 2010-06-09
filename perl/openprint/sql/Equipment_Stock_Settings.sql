CREATE TABLE Equipment_Stock_Settings (
	id	SERIAL,
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (id),
	stock_id		INTEGER NOT NULL, FOREIGN KEY (stock_id) REFERENCES Papers (id),
	grain			TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX Equipment_Stock_Settings_idx on Equipment_Stock_Settings (equipment_id,stock_id);
