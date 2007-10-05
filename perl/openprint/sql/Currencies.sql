DROP TABLE Currencies;
DROP SEQUENCE Currency_Id_seq;
CREATE SEQUENCE Currency_Id_seq;

CREATE TABLE Currencies (
	Id	INTEGER DEFAULT nextval('Currency_id_seq'),
	Name		TEXT NOT NULL,
	Short		TEXT,
	Symbol		char(1) NOT NULL,
    PRIMARY KEY ( id )
);
INSERT INTO Currencies VALUES (nextval('Currency_Id_seq'),'Canadian Dollars','$');
INSERT INTO Currencies VALUES (nextval('Currency_Id_seq'),'US Dollars','$');

