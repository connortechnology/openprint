DROP TABLE iF EXISTS Services;

CREATE TABLE Services (
	id				SERIAL NOT NULL,
	category_id		INTEGER,
	name 			TEXT NOT NULL, UNIQUE(name),
	description		TEXT,
    supplier_id		INTEGER,
	taxexempt1		char(1) NOT NULL DEFAULT 'N',
	taxexempt2		char(1) NOT NULL DEFAULT 'N',
	strUrl			TEXT,
	lngSortOrder	INTEGER,
	activity_code	TEXT,
	servicetype_id	INTEGER, FOREIGN KEY (servicetype_id) REFERENCES service_types (id),
	owner_id		INTEGER, FOREIGN KEY (owner_id) REFERENCES Companies(id),
	PRIMARY KEY (id)
);
 
