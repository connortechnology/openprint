CREATE TABLE Equipment_Categories (
    id  	SERIAL NOT NULL,
    name    TEXT NOT NULL,
    PRIMARY KEY (id)
);
CREATE INDEX Equipment_Categories_idx on Equipment_Categories (name);

INSERT INTO Equipment_Categories (name) values ('Bindery');
INSERT INTO Equipment_Categories (name) values ('Printing');
INSERT INTO Equipment_Categories (name) values ('Packaging');
INSERT INTO Equipment_Categories (name) values ('Prepress');
INSERT INTO Equipment_Categories (name) values ('Manual');
INSERT INTO Equipment_Categories (name) values ('Shipping');
