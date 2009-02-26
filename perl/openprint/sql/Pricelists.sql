DROP TABLE IF EXISTS Pricelists;
DROP SEQUENCE IF EXISTS Pricelists_id_seq;

CREATE SEQUENCE Pricelist_id_seq;
CREATE TABLE Pricelists (
    id		SERIAL,
	owner_id	INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (id),
	Name		TEXT,
	Description	TEXT,
	currency_id	INTEGER, FOREIGN KEY (currency_id) REFERENCES Currencies (id),
	PRIMARY KEY ( id )
);
