DROP TABLE iF EXISTS Services;

CREATE TABLE Services (
	id				SERIAL NOT NULL,
	category_id		INTEGER,
	name 			TEXT NOT NULL, UNIQUE(name),
	description		TEXT,
    Supplier_id		INTEGER,
	TaxExempt1		char(1) NOT NULL DEFAULT 'N',
	TaxExempt2		char(1) NOT NULL DEFAULT 'N',
	strUrl			TEXT,
	lngSortOrder	INTEGER,
	PRIMARY KEY (id)
);
 
