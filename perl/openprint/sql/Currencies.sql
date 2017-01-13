CREATE SEQUENCE Currency_id_seq;

CREATE TABLE Currencies (
	id	INTEGER DEFAULT nextval('Currency_id_seq'),
	name		TEXT NOT NULL,
	short		TEXT,
	symbol		char(4) NOT NULL,/* 4 to support unicode */
    PRIMARY KEY ( id )
);
INSERT INTO Currencies VALUES (nextval('Currency_id_seq'),'Canadian Dollars','CAD','$');
INSERT INTO Currencies VALUES (nextval('Currency_id_seq'),'US Dollars','USD','$');

