DROP TABLE IF EXISTS EmployeeNumbers;

CREATE TABLE EmployeeNumbers (
		ID SERIAL NOT NULL,
		Min INTEGER,
		Max INTEGER,
		PRIMARY KEY(id)
);

INSERT INTO EmployeeNumbers VALUES ( nextval('EmployeeNumbers_id_seq'), '1', '10' );
INSERT INTO EmployeeNumbers VALUES ( nextval('EmployeeNumbers_id_seq'), '10', '50' );
INSERT INTO EmployeeNumbers VALUES ( nextval('EmployeeNumbers_id_seq'), '50', '100' );
INSERT INTO EmployeeNumbers VALUES ( nextval('EmployeeNumbers_id_seq'), '100', '500' );
INSERT INTO EmployeeNumbers VALUES ( nextval('EmployeeNumbers_id_seq'), '500', NULL );
