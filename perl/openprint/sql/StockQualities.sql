CREATE TABLE StockQualities (
    id  SERIAL,
    name    TEXT NOT NULL UNIQUE,
	message	TEXT,
    PRIMARY KEY (id)
);

