DROP TABLE IF EXISTS PurchaseOrder_Departments;

CREATE TABLE PurchaseOrder_Departments (
	id 		SERIAL,
	name	TEXT NOT NULL,
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX PurchaseOrder_Departments_name_idx ON PurchaseOrder_Departments (name);
