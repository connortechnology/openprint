DROP TABLE tbl_Services;
DROP SEQUENCE ServiceIndex_seq;
CREATE SEQUENCE ServiceIndex_seq;

CREATE TABLE tbl_Services (
	lngIndex		INT4 DEFAULT nextval('ServiceIndex_seq'),
	lngCategoryIndex	INT4,
	strID 				TEXT, UNIQUE(strID),
	strName				TEXT,
	strDescription		TEXT,
	strDetails			TEXT,
    lngSupplierIndex	INT4,
	ysnTaxExempt1		char(1) NOT NULL DEFAULT 'N',
	ysnTaxExempt2		char(1) NOT NULL DEFAULT 'N',
	strUrl				TEXT,
	lngSortOrder		INT4,
	PRIMARY KEY (lngIndex)
);
 
CREATE INDEX ServiceID ON tbl_Services (strID);

