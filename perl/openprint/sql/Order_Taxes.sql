CREATE TABLE Order_Taxes (
    id  SERIAL,
    order_id  INTEGER NOT NULL, FOREIGN KEY (order_id) REFERENCES Orders (index),
    tax_id      INTEGER NOT NULL, FOREIGN KEY (tax_id) REFERENCES Taxes (id),
    rate        float,
    amount      float,
	charge		boolean default true,
    PRIMARY KEY (id)
);

