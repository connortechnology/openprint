CREATE TABLE PurchaseOrder_Taxes (
    id  SERIAL,
    purchaseorder_id  INTEGER NOT NULL, FOREIGN KEY (purchaseorder_id) REFERENCES PurchaseOrder (id),
    tax_id      INTEGER NOT NULL, FOREIGN KEY (tax_id) REFERENCES Taxes (id),
    rate        float,
    amount      float,
    PRIMARY KEY (id)
);

