DROP TABLE Currency_Conversions;

CREATE TABLE Currency_Conversions (
	from_id		INTEGER NOT NULL, FOREIGN KEY (from_id) REFERENCES Currencies (id),
	to_id			INTEGER NOT NULL, FOREIGN KEY (to_id) REFERENCES Currencies (id),
	rate		float NOT NULL,
    PRIMARY KEY ( from_id, to_id )
);

