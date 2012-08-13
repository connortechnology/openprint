CREATE TABLE Equipment_Categories (
    id  	SERIAL NOT NULL,
    name    TEXT NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX Equipment_Categories_idx on Equipment_Categories (name);
