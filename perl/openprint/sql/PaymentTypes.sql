CREATE TABLE PaymentTypes (
	id SERIAL NOT NULL,
	name	TEXT,
	description	TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	PRIMARY KEY (id)
);
