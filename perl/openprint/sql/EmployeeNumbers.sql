DROP TABLE EmployeeNumbers;
DROP SEQUENCE EmployeeNumbers_id_seq;
CREATE SEQUENCE EmployeeNumbers_id_seq;

CREATE TABLE EmployeeNumbers (
		ID INT2 NOT NULL default nextval('EmployeeNumbers_id_seq'),
		Min INT4,
		Max INT4,
		PRIMARY KEY(id)
);

INSERT INTO EmployeeNumbers VALUES ( nextval('EmployeeNumbers_id_seq'), '1', '10' );
INSERT INTO EmployeeNumbers VALUES ( nextval('EmployeeNumbers_id_seq'), '10', '50' );
INSERT INTO EmployeeNumbers VALUES ( nextval('EmployeeNumbers_id_seq'), '50', '100' );
INSERT INTO EmployeeNumbers VALUES ( nextval('EmployeeNumbers_id_seq'), '100', '500' );
INSERT INTO EmployeeNumbers VALUES ( nextval('EmployeeNumbers_id_seq'), '500', NULL );
