CREATE TABLE Bitcoin_Addresses (
	id		SERIAL,
	address	TEXT NOT NULL,
    object_type_id  INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
    object_id   INTEGER,
	PRIMARY KEY (id)
);
