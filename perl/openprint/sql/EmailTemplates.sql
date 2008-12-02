DROP TABLE IF EXISTS EmailTemplates;

CREATE TABLE EmailTemplates (
	id			SERIAL NOT NULL,
	created_on	timestamp with time zone NOT NULL default NOW(),
	updated_on	timestamp with time zone NOT NULL default NOW(),
	name		TEXT,
	body		TEXT,
	deleted		BOOLEAN NOT NULL default false,
	PRIMARY KEY (id)
);
