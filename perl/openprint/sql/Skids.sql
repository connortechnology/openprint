DROP TABLE IF EXISTS Skid_verifications;
DROP TABLE IF EXISTS Skid_Contents;
DROP TABLE IF EXISTS Skids;
DROP SEQUENCE Skid_id_seq;

CREATE SEQUENCE Skid_id_seq;
CREATE TABLE Skids (
	id	SERIAL NOT NULL,
	location	TEXT,
	rfidtag_id	TEXT,
	created_on	timestamp with time zone default NOW(),
	updated_on	timestamp with time zone default NOW(),
	created_by_id	INTEGER NOT NULL,  FOREIGN KEY (created_by_id) REFERENCES Users (Id),
	owner_id		INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (Id),
	type			TEXT,
	PRIMARY KEY (id)
);

CREATE TABLE Skid_Contents (
	skid_id	INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES skids (id),
	paper_id	INTEGER NOT NULL, FOREIGN KEY (paper_id) REFERENCES papers (id),
	quantity	INTEGER NOT NULL
)

CREATE TABLE skid_verifications (
	id SERIAL NOT NULL,
	skid_id	INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES skids (id),
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (index),
	code	TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	PRIMARY KEY (id)
);
CREATE INDEX skid_verifications_skid_id_idx ON skid_verifications (skid_id);
CREATE INDEX skid_verifications_code_idx ON skid_verifications (code);
