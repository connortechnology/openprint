DROP TABLE IF EXISTS Skid_Contents;

CREATE TABLE Skid_Contents (
	skid_id	INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES skids (id),
	paper_id	INTEGER NOT NULL, FOREIGN KEY (paper_id) REFERENCES papers (id),
	quantity	INTEGER NOT NULL
);
