DROP SEQUENCE Assistants_id_seq;
DROP TABLE Assistants;

CREATE SEQUENCE Assistants_id_seq;

CREATE TABLE Assistants (
	id INTEGER NOT NULL default nextval('Assistants_id_seq'),
	csr_id	INTEGER NOT NULL, FOREIGN KEY (csr_id) REFERENCES Users (index),
	assistant_id	INTEGER NOT NULL, FOREIGN KEY (assistant_id) REFERENCES Users (index),
	PRIMARY KEY (id)
);

