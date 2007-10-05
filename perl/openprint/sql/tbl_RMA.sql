DROP	SEQUENCE	RMA_Index_seq;
CREATE	SEQUENCE	RMA_Index_seq;
DROP TABLE tbl_RMA;

CREATE TABLE tbl_RMA (
	lngIndex			INT4 NOT NULL default nextval('RMA_Index_seq'),
	lngCustomerIndex	INT4 NOT NULL, FOREIGN KEY (lngCustomerIndex) REFERENCES tbl_Customer (lngCustomerID),
	lngUserIndex		INT4 NOT NULL,
	lngProjectIndex 	INT4 NOT NULL, 
	lngOrderID 			INT8 NOT NULL, /* FOREIGN KEY (lngOrderID) REFERENCES tbl_Orders (lngOrderID), */
	chrRMAType 			char(1) DEFAULT '' NOT NULL,
	dtmRequestDate 		date NOT NULL,
	strDescription		TEXT,
	txtComments			TEXT,
	strRMANumber		TEXT,
	ysnApprove 			char(1),
	PRIMARY KEY (lngIndex)
);

