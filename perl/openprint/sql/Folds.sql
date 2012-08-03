/*
DROP TABLE IF EXISTS Fold_Specifications;
DROP SEQUENCE IF EXISTS FoldSpecification_id_seq;
CREATE SEQUENCE FoldSpecification_id_seq;

DROP TABLE IF EXISTS Folds;
DROP SEQUENCE IF EXISTS Fold_id_seq;
CREATE SEQUENCE Fold_id_seq;
*/

CREATE TABLE Folds (
	id SERIAL,
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (Id),
	type	TEXT,
	name	TEXT,
	folds			INTEGER,
	angles			INTEGER,
	pages			INTEGER,
	page_columns	INTEGER,
	page_rows		INTEGER,
	min_width		float,
	min_height		float,
	max_width		float,
	max_height		float,
	min_calliper	float,
	max_calliper	float,
	min_gsm			float,
	max_gsm			float,
	min_imposition	INTEGER,
	max_imposition	INTEGER,
	cutting			boolean,
	stitching		boolean,
	perfectbind		boolean,
	spinepaste		boolean,
	spine_direction	TEXT,
	makeready_time	integer,
	makeready_overs	integer,
	makeready_overs_units	TEXT,
	run_overs	integer,
	run_overs_units	TEXT,
	printing_type	TEXT,
	PRIMARY KEY (id)
);

