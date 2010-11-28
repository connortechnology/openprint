DROP TABLE IF EXISTS Taxes;

CREATE TABLE Taxes (
	id	SERIAL,
	rate NUMERIC(10,2),
	state char(2),
	country char(2),
	period_start	DATE,
	period_end		DATE,
	name	text,
  PRIMARY KEY (id)
);
CREATE INDEX Taxes_idx ON Taxes (country,state);


