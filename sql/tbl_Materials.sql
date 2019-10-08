DROP TABLE tbl_Materials;
DROP SEQUENCE MaterialIndex_seq;
CREATE SEQUENCE MaterialIndex_seq;

CREATE TABLE tbl_Materials (
	lngIndex			INT4 DEFAULT nextval('MaterialIndex_seq'),
	lngCategoryIndex	INT4, 
	strID 				TEXT, UNIQUE(strID),
	strName				TEXT,
	strDescription		TEXT,
	strDetails			TEXT,
    lngSupplierIndex	INT4,
	ysnTaxExempt1		char(1) NOT NULL DEFAULT 'N',
	ysnTaxExempt2		char(1) NOT NULL DEFAULT 'N',
	PRIMARY KEY (lngIndex)
);
 
CREATE INDEX MaterialID_Index ON tbl_Materials (strID);
