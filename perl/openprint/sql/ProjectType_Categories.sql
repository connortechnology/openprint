DROP SEQUENCE ProjectType_Categories_id_seq;
CREATE SEQUENCE ProjectType_Categories_id_seq;

DROP TABLE ProjectType_Categories;
CREATE TABLE ProjectType_Categories (
	id	INTEGER NOT NULL DEFAULT nextval('ProjectType_Categories_id_seq'),
	name TEXT,
	primary key (id)
);
