DROP TABLE Pricelists;
DROP SEQUENCE PricelistIndex_seq;

CREATE SEQUENCE PricelistIndex_seq;
CREATE TABLE Pricelists (
    Index		INT4	NOT NULL default nextval('PricelistIndex_seq'),
	Name		TEXT,
	Description	TEXT,
	CurrencyIndex	INT2, FOREIGN KEY (CurrencyIndex) REFERENCES Currency (Index),
	PRIMARY KEY ( Index )
);
