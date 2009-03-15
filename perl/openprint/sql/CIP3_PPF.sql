DROP TABLE IF EXISTS CIP3_PPF;
CREATE TABLE CIP3_PPF (
	id	SERIAL,
	docket		INTEGER NOT NULL,
	signature	INTEGER,
	side		text,
	data		text,
	PRIMARY KEY (id)
);

CREATE INDEX CIP3_PPF_docket_idx ON CIP3_PPF (docket);
