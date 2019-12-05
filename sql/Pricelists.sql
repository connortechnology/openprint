DROP TABLE IF EXISTS Pricelists;
CREATE TABLE Pricelists (
    id		SERIAL,
	owner_id	INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (id),
	Name		TEXT,
	Description	TEXT,
	currency_id	INTEGER, FOREIGN KEY (currency_id) REFERENCES Currencies (id),
	deleted					BOOLEAN NOT NULL default false,
	PRIMARY KEY ( id )
);
