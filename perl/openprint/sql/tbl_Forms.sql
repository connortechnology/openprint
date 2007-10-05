
DROP TABLE tbl_Forms;
DROP SEQUENCE forms_index_seq;
CREATE SEQUENCE forms_index_seq;

CREATE TABLE tbl_Forms (
	lngIndex				INT4 NOT NULL DEFAULT nextval('forms_index_seq'),
	strURL					TEXT NOT NULL,
	strName					TEXT NOT NULL,
	strInputTable			TEXT NOT NULL,
	strInputFieldName		TEXT NOT NULL,
	strInputFieldTransform	TEXT NOT NULL,
	strInputDBFieldName		TEXT NOT NULL,
	strOutputTable			TEXT NOT NULL,
	strOutputFieldName		TEXT NOT NULL,
	strOutputFieldTransform	TEXT NOT NULL,
	strOutputDBFieldName	TEXT NOT NULL
);

