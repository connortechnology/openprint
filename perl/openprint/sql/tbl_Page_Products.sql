DROP TABLE tbl_Page_Products;
DROP SEQUENCE tbl_Page_Products_lngIndex_seq;
CREATE SEQUENCE tbl_Page_Products_lngIndex_seq;

DROP INDEX tbl_page_products_pkey;

CREATE TABLE tbl_page_Products (
  lngIndex INT4 DEFAULT nextval('tbl_Page_Products_lngIndex_se'),
  strPage varchar(50),
  strProductIndex INT4,
  PRIMARY KEY (lngIndex)
);
 
