DROP	TABLE tbl_Customer_Credit;
CREATE	TABLE tbl_Customer_Credit (
	lngCustomerIndex	INT4, FOREIGN KEY (lngCustomerIndex) REFERENCES tbl_Customer (lngCustomerID),
	lngSupplierIndex	INT4, FOREIGN KEY (lngSupplierIndex) REFERENCES tbl_Customer (lngCustomerID),
	dblCreditLimit		NUMERIC(10,2),
	lngTerms			INT4,
	dblDownpayment      NUMERIC(10,2),
	ysnCreditHold		CHAR(1) DEFAULT 'N'
);
