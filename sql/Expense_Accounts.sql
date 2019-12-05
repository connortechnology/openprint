DROP TABLE IF EXISTS Expense_Accounts;

CREATE TABLE Expense_Accounts (
    id      SERIAL,
    name    TEXT NOT NULL,
    PRIMARY KEY (id)
);

