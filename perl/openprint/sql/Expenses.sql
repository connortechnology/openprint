
DROP TABLE IF EXISTS Expenses;
DROP TABLE IF EXISTS Expense_Categories;

CREATE TABLE Expense_Categories (
	id		SERIAL,
	name	TEXT NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE Expenses (
	id	SERIAL,
	amount	float,
	amount_locked 	BOOLEAN NOT NULL default false,
	total	float,
	total_locked 	BOOLEAN NOT NULL default false,
	recipient_id	INTEGER, FOREIGN KEY (recipient_id) REFERENCES companies (id),
	category_id	INTEGER NOT NULL, FOREIGN KEY (category_id) REFERENCES Expense_Categories (id),
	account_id	INTEGER NOT NULL, FOREIGN KEY (account_id) REFERENCES Expense_Accounts (id),
	owner_id	INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (id),
	description	TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	due_on	TIMESTAMP WITH TIME ZONE,
	invoiced_on	TIMESTAMP WITH TIME ZONE,
	currency_id	INTEGER NOT NULL, FOREIGN KEY (currency_id) REFERENCES Currencies (id),
	business_use	float,
	business_use_amount	float,
	PRIMARY KEY (id)
);

create index expenses_deleted_owner_id_created_on_idx on expenses (deleted,owner_id,created_on);
create index expenses_deleted_owner_id_paid_on_idx on expenses (deleted,owner_id,paid_on);

