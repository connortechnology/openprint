CREATE TABLE Claim_Taxes (
    id  SERIAL,
    claim_id  INTEGER NOT NULL, FOREIGN KEY (claim_id) REFERENCES Claims (id),
    tax_id      INTEGER NOT NULL, FOREIGN KEY (tax_id) REFERENCES Taxes (id),
    rate        float,
    amount      float,
	charge		boolean default true,
    PRIMARY KEY (id)
);

