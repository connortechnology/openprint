CREATE TABLE PurchaseOrder_Taxes (
    id  SERIAL,
    purchaseorder_id  INTEGER NOT NULL, FOREIGN KEY (purchaseorder_id) REFERENCES PurchaseOrders (id),
    tax_id      INTEGER NOT NULL, FOREIGN KEY (tax_id) REFERENCES Taxes (id),
    rate        float,
    amount      float,
	charge		boolean,
    PRIMARY KEY (id)
);

