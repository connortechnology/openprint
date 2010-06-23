
CREATE TABLE Quoted_Products (
	id SERIAL,
	product_id	INTEGER NOT NULL,
	quote_id	INTEGER NOT NULL, FOREIGN KEY (quote_id) REFERENCES Quotes (id),
	quantity	INTEGER,
	cost		float,
	price		float,
	markup		float,
	PRIMARY KEY (id)
);
