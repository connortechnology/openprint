DROP TABLE iF EXISTS Skid_Contents;
DROP TABLE iF EXISTS Skids;

CREATE SEQUENCE Skid_id_seq;
CREATE TABLE Skids (
	id	SERIAL NOT NULL,
	location	TEXT,
	rfidtag_id	TEXT,
	created_on	timestamp with time zone default NOW(),
	updated_on	timestamp with time zone default NOW(),
	created_by_id	INTEGER NOT NULL,  FOREIGN KEY (created_by_id) REFERENCES Users (Id),
	owner_id		INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (Id),
	PRIMARY KEY (id)
);

CREATE TABLE Skid_Contents (
	skid_id	INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES skids (id),
	paper_id	INTEGER NOT NULL, FOREIGN KEY (paper_id) REFERENCES papers (id),
	quantity	INTEGER NOT NULL
)


