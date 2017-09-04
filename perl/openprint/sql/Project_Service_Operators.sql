CREATE TABLE Project_Service_Operators (
	id	SERIAL,
	service_id	INTEGER, FOREIGN KEY (service_id) REFERENCES tbl_Project_Contents (lngServiceIndex),
	role_id			INTEGER, FOREIGN KEY (role_id) REFERENCES Operator_Roles (id),
	user_id			INTEGER, FOREIGN KEY (user_id) REFERENCES Users (id),
	PRIMARY KEY (id)
);

CREATE INDEX Project_Service_Operators_service_id_idx ON Project_Service_Operators (service_id);
