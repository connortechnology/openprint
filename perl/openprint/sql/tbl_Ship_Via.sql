DROP TABLE tbl_Ship_Via;

DROP SEQUENCE lngShipViaIndex_seq;
CREATE SEQUENCE lngShipViaIndex_seq;

CREATE TABLE tbl_Ship_Via (
	lngIndex	INT2 NOT NULL default nextval('lngShipViaIndex_seq'),
    strName 	TEXT NOT NULL,
	PRIMARY KEY (lngIndex)
);

INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'C.O.D.');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'Canada Post');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'Deliver');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'DHL');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'Federal Express');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'Fedex Economy');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'Fedex Priority');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'Fedex Standard');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'Purolator');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'Trucking');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'UPS Blue');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'UPS Ground');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'UPS Orange');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'UPS Red');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'US Mail');
INSERT INTO tbl_Ship_Via VALUES (nextval('lngShipViaIndex_seq'),'Walk In');

