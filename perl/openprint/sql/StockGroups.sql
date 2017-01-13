CREATE TABLE StockGroups (
    id  SERIAL NOT NULL,
    name    TEXT NOT NULL UNIQUE,
    PRIMARY KEY (id)
);

