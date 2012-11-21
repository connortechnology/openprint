
/* DROP TABLE RMA_Statuses; */

CREATE TABLE RMA_Statuses (
	id		SERIAL,
	name	TEXT,
	sort	INTEGER,
	PRIMARY KEY (id)
);

INSERT INTO RMA_Statuses (name,sort) values ('Submitted',1);
INSERT INTO RMA_Statuses (name,sort) values ('Approved',2);
INSERT INTO RMA_Statuses (name,sort) values ('Units Received',3);
INSERT INTO RMA_Statuses (name,sort) values ('Start Assessment',4);
INSERT INTO RMA_Statuses (name,sort) values ('No Problem Found',5);
INSERT INTO RMA_Statuses (name,sort) values ('Start Repair',5);
INSERT INTO RMA_Statuses (name,sort) values ('Repair Complete',6);
INSERT INTO RMA_Statuses (name,sort) values ('Window Test',7);
INSERT INTO RMA_Statuses (name,sort) values ('Wait For Shipping',8);
INSERT INTO RMA_Statuses (name,sort) values ('Shipped',9);
