CREATE TABLE Assistants (
	id SERIAL,
	csr_id	INTEGER NOT NULL, FOREIGN KEY (csr_id) REFERENCES Users (id),
	assistant_id	INTEGER NOT NULL, FOREIGN KEY (assistant_id) REFERENCES Users (id),
	PRIMARY KEY (id)
);

