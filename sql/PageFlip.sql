CREATE TABLE pageflip (
	id SERIAL,
	docket	INTEGER NOT NULL,
	company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES company (index),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	page_Files	TEXT[],
	PRIMARY KEY (id)
);
