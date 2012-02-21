DROP TABLE IF EXISTS PurchaseOrder_Departments;

CREATE TABLE PurchaseOrder_Departments (
	id 		SERIAL,
	name	TEXT NOT NULL,
	PRIMARY KEY (id)
);
CREATE UNIQUE INDEX PurchaseOrder_Departments_name_idx ON PurchaseOrder_Departments (name);
alter table purchaseorder_contents add department_id INTEGER;
alter table purchaseorder_contents add FOREIGN KEY (department_id) REFERENCES purchaseorder_departments (id);

