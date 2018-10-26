CREATE TABLE Operator_Roles (
	id SERIAL,
	name	TEXT,
	servicetype_id	INTEGER, FOREIGN KEY (servicetype_id) REFERENCES service_types (id),
	sorting	integer,
	PRIMARY KEY (id)
);
