DROP TABLE IF EXISTS Fold_Specifications;
DROP SEQUENCE IF EXISTS FoldSpecification_id_seq;
CREATE SEQUENCE FoldSpecification_id_seq;

DROP TABLE IF EXISTS Folds;
DROP SEQUENCE IF EXISTS Fold_id_seq;
CREATE SEQUENCE Fold_id_seq;

CREATE TABLE Folds (
	id INTEGER NOT NULL default nextval('Fold_id_seq'),
	equipment_id	INTEGER NOT NULL, FOREIGN KEY (equipment_id) REFERENCES tbl_Equipment (lngIndex),
	type	TEXT,
	name	TEXT,
	pages			INTEGER,
	page_columns	INTEGER,
	page_rows		INTEGER,
	min_width		float,
	min_height		float,
	max_width		float,
	max_height		float,
	min_imposition	INTEGER,
	max_imposition	INTEGER,
	min_calliper	float,
	max_calliper	float,
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
	folds			INTEGER,
	angles			INTEGER,
	PRIMARY KEY (id)
);

CREATE TABLE Fold_Specifications (
	id	INTEGER NOT NULL default nextval('FoldSpecification_id_seq'),
	fold_id			INTEGER NOT NULL, FOREIGN KEY (fold_id) REFERENCES Folds (id),
	min_weight		float,
	max_weight		float,
	weight_units	TEXT,
	runspeed		INTEGER,
	interpolate		BOOLEAN,
	PRIMARY KEY (fold_id, id)
);
