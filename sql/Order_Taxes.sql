CREATE TABLE Order_Taxes (
    id  SERIAL,
    order_id  INTEGER NOT NULL, FOREIGN KEY (order_id) REFERENCES Orders (id),
    tax_id      INTEGER NOT NULL, FOREIGN KEY (tax_id) REFERENCES Taxes (id),
    rate        float,
    amount      float,
	charge		boolean default true,
    PRIMARY KEY (id)
);

create index order_taxes_order_id_tax_id_idx on order_taxes (order_id,tax_id);
