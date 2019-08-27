
CREATE TABLE RMA_Types (
	id	SERIAL,
	name	TEXT,
	PRIMARY KEY (id)
);

INSERT INTO RMA_Types (name) values ('Credit');
INSERT INTO RMA_Types (name) values ('Repair');
INSERT INTO RMA_Types (name) values ('Replacement');
/* INSERT INTO RMA_Types (name) values ('Re-Production'); */
