DROP TABLE IF EXISTS Currencies;
DROP SEQUENCE Currency_id_seq;
CREATE SEQUENCE Currency_id_seq;

CREATE TABLE Currencies (
	id	INTEGER DEFAULT nextval('Currency_id_seq'),
	name		TEXT NOT NULL,
	short		TEXT,
	symbol		char(1) NOT NULL,
    PRIMARY KEY ( id )
);
INSERT INTO Currencies VALUES (nextval('Currency_Id_seq'),'Canadian Dollars','$');
INSERT INTO Currencies VALUES (nextval('Currency_Id_seq'),'US Dollars','$');

