CREATE TABLE Expense_Rule_Categories (
	id 			SERIAL NOT NULL,
	name		TEXT, UNIQUE(Name),
	PRIMARY KEY (Id)
);
