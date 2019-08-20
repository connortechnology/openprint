DROP TABLE IF EXISTS Claim_Payments;
CREATE TABLE Claim_Payments (
	id	SERIAL,
	payment_id	INTEGER NOT NULL, FOREIGN KEY (payment_id) REFERENCES Payments (id),
	claim_id	INTEGER NOT NULL, FOREIGN KEY (claim_id) REFERENCES Claims (id),
	amount		float,
	PRIMARY KEY (id)
);

CREATE INDEX claim_payments_idx on claim_payments (claim_id,payment_id);
