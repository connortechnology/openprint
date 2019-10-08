
CREATE TABLE Fold_Specifications (
	id	SERIAL,
	fold_id			INTEGER NOT NULL, FOREIGN KEY (fold_id) REFERENCES Folds (id),
	min_weight		float,
	max_weight		float,
	weight_units	TEXT,
	runspeed		INTEGER,
	interpolate		BOOLEAN,
	PRIMARY KEY (fold_id, id)
);
