CREATE TABLE Paper_Sheets (
	paper_id	INTEGER NOT NULL, FOREIGN KEY (paper_id) REFERENCES Papers (id),
	width		float NOT NULL,
	height		float NOT NULL,
	mweight		float NOT NULL,
	PRIMARY KEY (paper_id)
);
