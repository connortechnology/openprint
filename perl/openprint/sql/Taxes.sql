DROP TABLE Taxes;

CREATE TABLE Taxes (
  dblStatePercent NUMERIC(10,2),
  dblFederalPercent NUMERIC(10,2),
  dblHarmonisedPercent NUMERIC(10,2),
  State char(2),
	country char(2),
	name	text,
  PRIMARY KEY (Country, State)
);


