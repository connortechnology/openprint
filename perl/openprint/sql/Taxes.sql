DROP TABLE Taxes;

CREATE TABLE Taxes (
  dblStatePercent NUMERIC(10,2),
  dblFederalPercent NUMERIC(10,2),
  dblHarmonisedPercent NUMERIC(10,2),
  State char(2),
	Country char(2),
  PRIMARY KEY (Country, State)
);


