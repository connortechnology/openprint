DROP TABLE tbl_Warehouse;

DROP SEQUENCE lngWarehouseID_seq;
CREATE SEQUENCE lngWarehouseID_seq;

DROP INDEX tbl_warehouse_pkey;

CREATE TABLE tbl_Warehouse (
  lngWarehouseID        INT4 DEFAULT nextval('lngWarehouseID_seq'),
  strDescription        varchar(255),
  strAddress1 			varchar(30),
  strAddress2			varchar(30),                                 
  strCity				varchar(15),
  strStateProvince		varchar(15),
  strZipPostalCode 		varchar(10),
  strCountry 			varchar(15),
  strNotes 				varchar(255),
  PRIMARY KEY (lngWarehouseID)
);


