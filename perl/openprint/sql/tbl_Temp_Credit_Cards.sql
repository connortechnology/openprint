DROP TABLE tbl_Temp_Credit_Cards;

CREATE TABLE tbl_Temp_Credit_Cards (
    lngPaymentIndex	INT4 NOT NULL,
    strExpiryDate   CHAR(4) NOT NULL,
    strHolder       CHAR(100) NOT NULL,
    strCardType     CHAR(25) NOT NULL, /* American Express is 15 chars */
    strCardNumber   CHAR(16) NOT NULL,
    dtmCreatedDate  datetime NOT NULL
);

