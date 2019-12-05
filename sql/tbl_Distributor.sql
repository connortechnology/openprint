
DROP TABLE tbl_Distributor;
DROP INDEX tbl_Distributor_pkey;
DROP SEQUENCE tbl_Dist_lngDistributor_seq;
CREATE SEQUENCE tbl_Dist_lngDistributorID_seq;


CREATE TABLE tbl_Distributor (
  lngDistributorID INT4 DEFAULT nextval('tbl_Dist_lngDistributorID_seq'),
  strDistributor char(50),
  strContactName char(35),
  strAddress1 char(35),
  strAddress2 char(35),
  strCounty char(25),
  strCity char(25),
  strStateProvince char(2),
  strZipPostalCode char(12),
  strCountry char(25),
  strPhone1 char(25),
  strPhone2 char(25),
  strNotes char(255),
  strWebURL char(255),
  strEmail  char(50),
  PRIMARY KEY (lngDistributorID)
);

INSERT INTO tbl_Distributor VALUES (1,'Direction Main Branch',NULL,'34 King St. South',NULL,'','Kitchener','ON','N2E 4E9','CANADA','(519) 894-6514',NULL,NULL,NULL,NULL);
INSERT INTO tbl_Distributor VALUES (2,'Direction Annex',NULL,'54 Duke St. North',NULL,'CANADA','Kitchener','ON','N2E 2E9','CANADA','(519) 894-6515',NULL,NULL,NULL,NULL);
INSERT INTO tbl_Distributor VALUES (3,'Cambridge ',NULL,'34 Eagle St. South',NULL,'CANADA','Cambridge','ON','N1R 4G9','CANADA','(519) 678-4533',NULL,NULL,NULL,NULL);
INSERT INTO tbl_Distributor VALUES (4,'Burlington',NULL,'34 Pine St. South',NULL,'CANADA','Burlington','ON','L7N 1C6','CANADA','(519) 674-4543',NULL,NULL,NULL,NULL);
INSERT INTO tbl_Distributor VALUES (5,'Hamliton',NULL,'34 Trick St.',NULL,'CANADA','Hamilton','ON','L9A 4L6','CANADA','(439) 678-4533',NULL,NULL,NULL,NULL);
INSERT INTO tbl_Distributor VALUES (6,'London',NULL,'34 North St.',NULL,'CANADA','London','ON','N5Z 2K1','CANADA','(439) 678-4533',NULL,NULL,NULL,NULL);
INSERT INTO tbl_Distributor VALUES (7,'Mississauga',NULL,'34 West St.',NULL,'CANADA','Mississauga','ON','L5V 2G5','CANADA','(439) 678-4533',NULL,NULL,NULL,NULL);
INSERT INTO tbl_Distributor VALUES (8,'Oshawa',NULL,'34 East St.',NULL,'CANADA','Oshawa','ON','L1K 1K4','CANADA','(439) 678-4533',NULL,NULL,NULL,NULL);
INSERT INTO tbl_Distributor VALUES (9,'Ottawa',NULL,'34 West St.',NULL,'CANADA','Ottawa','ON','K2H 1B3','CANADA','(439) 678-4533',NULL,NULL,NULL,NULL);
INSERT INTO tbl_Distributor VALUES (10,'Montreal',NULL,'34 Leduc St.',NULL,'CANADA','Montreal','QU','H2C 1K1','CANADA','(439) 678-4533',NULL,NULL,NULL,NULL);

