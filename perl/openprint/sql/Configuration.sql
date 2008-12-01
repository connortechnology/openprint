DROP TABLE Configuration;

CREATE TABLE Configuration (
    Name		TEXT NOT NULL,
    Value		TEXT,
	Type		TEXT,
	Description	TEXT,
	Category	TEXT,
	PRIMARY KEY (Name)
);


