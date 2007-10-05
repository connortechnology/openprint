DROP SEQUENCE lngReportID_seq;
DROP INDEX tbl_reports_strreportname_key;
DROP INDEX tbl_reports_pkey;
DROP TABLE tbl_Reports;

CREATE SEQUENCE lngReportID_seq;

CREATE TABLE tbl_Reports (
  lngReportID INT4 DEFAULT nextval('lngReportID_seq'),
  strReportName varchar(25) ,UNIQUE(strReportName),
  strSQLCOmmand TEXT,
  PRIMARY KEY (lngReportID)
);


