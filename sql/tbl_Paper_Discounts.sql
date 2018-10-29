
DROP	SEQUENCE Paper_Discount_Index_seq;
CREATE	SEQUENCE Paper_Discount_Index_seq;
DROP	TABLE tbl_Paper_Discounts;
CREATE	TABLE tbl_Paper_Discounts (
	lngIndex	INT4 NOT NULL default nextval('Paper_Discount_Index_seq'),
	lngMin		INT4,
	lngMax		INT4,
	dblDiscount	NUMERIC(10,2),
	PRIMARY KEY (lngIndex)
);

INSERT INTO tbl_Paper_Discounts VALUES (nextval('Paper_Discount_Index_seq'), NULL, '20000', '0.00' );
INSERT INTO tbl_Paper_Discounts VALUES (nextval('Paper_Discount_Index_seq'), '20001', '40000', '0.01' );
INSERT INTO tbl_Paper_Discounts VALUES (nextval('Paper_Discount_Index_seq'), '40001', '100000', '0.02' );
INSERT INTO tbl_Paper_Discounts VALUES (nextval('Paper_Discount_Index_seq'), '100001', NULL, '0.03' );
