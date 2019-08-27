/* 
*/

CREATE TABLE StockBrands (
	id 	SERIAL,
	name	TEXT NOT NULL UNIQUE,
	PRIMARY KEY (id)
);

