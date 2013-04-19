
DROP TABLE IF EXISTS ProjectType_Categories;
CREATE TABLE ProjectType_Categories (
	id	SERIAL NOT NULL,
	name TEXT,
	sort	integer,
	primary key (id)
);
