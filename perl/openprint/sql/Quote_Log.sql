CREATE TABLE Quote_Log (
	id SERIAL NOT NULL,
	quote_id	INTEGER NOT NULL, FOREIGN KEY (quote_id) REFERENCES tbl_Quotes (Index),
	user_id	INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (index),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOw(),
description 	TEXT,
PRIMARY KEY (id)
);
