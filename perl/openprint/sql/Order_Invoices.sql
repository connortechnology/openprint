CREATE TABLE Order_Invoices (
    order_id  INTEGER NOT NULL, FOREIGN KEY (order_id) REFERENCES Orders (id),
    invoice_id      INTEGER NOT NULL, FOREIGN KEY (invoice_id) REFERENCES Invoices (id),
    PRIMARY KEY (order_id,invoice_id)
);

