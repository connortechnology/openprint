
CREATE TABLE Project_Statuses (
	id	SERIAL NOT NULL,
	name	TEXT NOT NULL,
	sort	integer,
	UNIQUE (name),
	PRIMARY KEY (id)
);

INSERT INTO Project_Statuses (name) VALUES ('uncalculated');
INSERT INTO Project_Statuses (name) VALUES ('Unordered');
INSERT INTO Project_Statuses (name) VALUES ('Pending Deposit');
INSERT INTO Project_Statuses (name) VALUES ('Ordered');
INSERT INTO Project_Statuses (name) VALUES ('In Prepress');
INSERT INTO Project_Statuses (name) VALUES ('Proofs Out');
INSERT INTO Project_Statuses (name) VALUES ('Waiting For Customer Approval');
INSERT INTO Project_Statuses (name) VALUES ('Waiting For QA Approval');
INSERT INTO Project_Statuses (name) VALUES ('Approved');
INSERT INTO Project_Statuses (name) VALUES ('Printed');
INSERT INTO Project_Statuses (name) VALUES ('Complete');
INSERT INTO Project_Statuses (name) VALUES ('Waiting For Pickup');
INSERT INTO Project_Statuses (name) VALUES ('Picked Up');
INSERT INTO Project_Statuses (name) VALUES ('Shipped');
INSERT INTO Project_Statuses (name) VALUES ('Deleted');
INSERT INTO Project_Statuses (name) VALUES ('Cancelled');
INSERT INTO Project_Statuses (name) VALUES ('In Production');
INSERT INTO Project_Statuses (name) VALUES ('Waiting For Files');
