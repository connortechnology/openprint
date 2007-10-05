DROP SEQUENCE Manufacturers_id_seq;
CREATE SEQUENCE Manufacturers_id_seq;

DROP TABLE Manufacturers;
CREATE TABLE Manufacturers (
		id  INTEGER NOT NULL default nextval('Manufacturers_id_seq'),
		shortname   TEXT NOT NULL,
		longname    TEXT NOT NULL,
		PRIMARY KEY (id)
		);

