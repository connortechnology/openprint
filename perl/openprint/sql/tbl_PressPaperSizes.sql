
DROP SEQUENCE tbl_PressPaperSizes_seq;
CREATE SEQUENCE tbl_PressPaperSizes_seq;


DROP TABLE tbl_PressPaperSizes;


CREATE TABLE tbl_PressPaperSizes (
  lngID INT8 DEFAULT nextval('tbl_PressPaperSizes_seq'),
  strPressType varchar(100),
  strPaperSize varchar(100),
  dblPaperSize NUMERIC(10,4),
  PRIMARY KEY (lngID)
);

