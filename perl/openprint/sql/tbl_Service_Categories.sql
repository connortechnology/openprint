DROP	TABLE tbl_Service_Categories;
DROP	SEQUENCE ServiceCategoriesIndex_seq;
CREATE	SEQUENCE ServiceCategoriesIndex_seq;

CREATE TABLE tbl_Service_Categories (
	lngIndex	INT4 DEFAULT nextval('ServiceCategoriesIndex_seq'),
	strID		TEXT,
	strName 	TEXT,
	PRIMARY KEY (lngIndex)
);

CREATE INDEX ServiceCategoryNameIndex ON tbl_Service_Categories (strName);
CREATE INDEX ServiceCategoryNameID ON tbl_Service_Categories (strID);
 
