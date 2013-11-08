DROP TABLE tbl_Trade_References;

CREATE TABLE tbl_Trade_References (
  lngCustomerID INT4 NOT NULL,
  strCompanyName varchar(50),
  strContact varchar(25),
  strPhone varchar(16),
  strExt varchar(10),
  strFax varchar(16),
  strEmail varchar(50),
  dblCreditLimit INT4,
  lngReferenceID INT2 NOT NULL
);
INSERT INTO tbl_Trade_References VALUES (1,'1','1','1','1','1','1',1,1);
INSERT INTO tbl_Trade_References VALUES (1,'2','2','2','2','2','2',2,2);
INSERT INTO tbl_Trade_References VALUES (1,'3','3','3','3','3','3',3,3);
INSERT INTO tbl_Trade_References VALUES (2,'1','1','1','1','1','1',1,1);
INSERT INTO tbl_Trade_References VALUES (2,'2','2','2','2','2','2',2,2);
INSERT INTO tbl_Trade_References VALUES (2,'3','3','3','3','3','3',3,3);

