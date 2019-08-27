CREATE TABLE Currency_Conversions (
	id	SERIAL,
	from_id		INTEGER NOT NULL, FOREIGN KEY (from_id) REFERENCES Currencies (id),
	to_id		INTEGER NOT NULL, FOREIGN KEY (to_id) REFERENCES Currencies (id),
	rate		float,
	period_start	TIMESTAMP WITH TIME ZONE,
	period_end		TIMESTAMP WITH TIME ZONE,
    PRIMARY KEY (id)
);

CREATE INDEX currency_conversions_to_from_period_end_idx ON currency_conversions (to_id,from_id,period_end);
