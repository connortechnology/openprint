DROP	TABLE tbl_Material_Categories;
DROP	SEQUENCE MaterialCategoriesIndex_seq;
CREATE	SEQUENCE MaterialCategoriesIndex_seq;

CREATE TABLE tbl_Material_Categories (
	lngIndex	INT4 DEFAULT nextval('MaterialCategoriesIndex_seq'),
	strID		TEXT,
	strName 	TEXT,
	PRIMARY KEY (lngIndex)
);

CREATE INDEX MaterialCategoryNameIndex ON tbl_Material_Categories (strName);
CREATE INDEX MaterialCategoryNameID ON tbl_Material_Categories (strID);
 
