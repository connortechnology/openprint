
DROP TABLE IF EXISTS Sites;

CREATE TABLE Sites (
	id SERIAL NOT NULL,
  company_id  INTEGER, FOREIGN KEY (company_id) REFERENCES Companies(id),
	name	TEXT, UNIQUE(name),
	created_on	timestamp with time zone not null default NOW(),
	updated_on	timestamp with time zone not null default NOW(),
	deleted		BOOLEAN NOT NULL DEFAULT FALSE,
	PRIMARY KEY (id)
);

CREATE INDEX Sites_Company_Id_idx ON Sites (company_id);
