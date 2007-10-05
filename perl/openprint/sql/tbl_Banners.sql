DROP TABLE tbl_Banners;
DROP SEQUENCE lngBannerIndex_seq;

CREATE SEQUENCE lngBannerIndex_seq;

CREATE TABLE tbl_Banners (
  lngIndex		INT4 DEFAULT nextval('lngBannerIndex_seq'),
  strName		TEXT, UNIQUE(strName),
  strImageURL	TEXT,
  strClickURL	TEXT,
  PRIMARY KEY (lngIndex)
);

