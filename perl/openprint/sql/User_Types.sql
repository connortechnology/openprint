DROP TABLE User_Types;

CREATE TABLE User_Types (
	identifier	char NOT NULL,
	label		TEXT NOT NULL
);

INSERT INTO User_Types VALUES('C', 'Customer');
INSERT INTO User_Types VALUES('A', 'Administrator');
INSERT INTO User_Types VALUES('E', 'Employee');
