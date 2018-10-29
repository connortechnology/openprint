DROP TABLE IF EXISTS Skid_Contents;

CREATE TABLE Skid_Contents (
	id		SERIAL,
	skid_id	INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES skids (id),
	paper_id	INTEGER NOT NULL, FOREIGN KEY (paper_id) REFERENCES papers (id),
	quantity	INTEGER NOT NULL,
	purpose_id	INTEGER, FOREIGN KEY (purpose_id) REFERENCES stock_Purposes (id),
	manifestcontent_id	INTEGER, FOREIGN KEY (manifestcontent_id) REFERENCES ManifestContents (id),
	condition_id	INTEGER,	FOREIGN KEY (condition_id) REFERENCES inventoryconditions (id),
	PRIMARY KEY (id)
);

