DROP TABLE IF EXISTS AnnualSales;
DROP SEQUENCE IF EXISTS AnnualSales_id_seq;
CREATE SEQUENCE AnnualSales_id_seq;

CREATE TABLE AnnualSales (
	id	INT2 NOT NULL default nextval('AnnualSales_id_seq'),
	Min	TEXT,
	Max	TEXT,
	PRIMARY KEY (id)
);
INSERT INTO AnnualSales VALUES ( nextval('AnnualSales_id_seq'), NULL, '$50000' );
INSERT INTO AnnualSales VALUES ( nextval('AnnualSales_id_seq'), '$50000', '$100000' );
INSERT INTO AnnualSales VALUES ( nextval('AnnualSales_id_seq'), '$100000', '$500000' );
INSERT INTO AnnualSales VALUES ( nextval('AnnualSales_id_seq'), '$500000', '$2000000' );
INSERT INTO AnnualSales VALUES ( nextval('AnnualSales_id_seq'), '$2000000', NULL );
