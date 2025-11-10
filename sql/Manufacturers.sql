DROP SEQUENCE IF EXISTS Manufacturers_id_seq;
CREATE SEQUENCE Manufacturers_id_seq;

DROP TABLE IF EXISTS Manufacturers;
CREATE TABLE Manufacturers (
		id  INTEGER NOT NULL default nextval('Manufacturers_id_seq'),
		name   TEXT NOT NULL,
		PRIMARY KEY (id)
		);

