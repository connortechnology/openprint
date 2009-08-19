DROP TABLE IF EXISTS CIP3_PPF;
CREATE TABLE CIP3_PPF (
	id				SERIAL,
	docket			INTEGER NOT NULL,
	signature		INTEGER,
	side			text,
	data			bytea,
	front_preview	bytea,
	back_preview	bytea,
	compressed		boolean default false,
	deleted			boolean default false,
	created_on		timestamp with time zone default now(),
	PRIMARY KEY (id)
);

CREATE INDEX CIP3_PPF_docket_idx ON CIP3_PPF (docket);
