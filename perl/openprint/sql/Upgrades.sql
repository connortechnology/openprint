CREATE TABLE Upgrades (
	id SERIAL,
	rma_id	INTEGER NOT NULL, FOREIGN KEY (rma_id) REFERENCES RMA (id),
	type_id	INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCES Upgrade_Types (id),
	old_version	TEXT,
	new_version TEXT,
	PRIMARY KEY (id)
);
