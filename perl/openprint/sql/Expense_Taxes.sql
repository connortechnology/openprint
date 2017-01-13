CREATE TABLE Expense_Taxes (
    id  SERIAL,
    expense_id  INTEGER NOT NULL, FOREIGN KEY (expense_id) REFERENCES Expenses (id),
    tax_id      INTEGER NOT NULL, FOREIGN KEY (tax_id) REFERENCES Taxes (id),
    rate        float,
    amount      float,
	charge		boolean default true,
    PRIMARY KEY (id)
);

CREATE INDEX expense_taxes_expense_id_tax_id_idx ON expense_taxes (expense_id,tax_id);
