DROP TABLE Order_Contents;

CREATE TABLE Order_Contents (
	OrderIndex 		INT4 NOT NULL,FOREIGN KEY(OrderIndex) REFERENCES Orders (Index),
	lngProjectIndex INT4 NOT NULL,FOREIGN KEY(lngProjectIndex) REFERENCES Projects (Index),
	strDescription	TEXT,
	intQuantity	 	INT4,
	intQuantityIndex 	INT4,
	dblTax1			NUMERIC(10,2),
	dblTax2			NUMERIC(10,2),
	dblTax3			NUMERIC(10,2),
	curSalesPrice	NUMERIC(20,2),
	dateRequired	date,
	dueDate			date,
	ShippingType	TEXT
);

