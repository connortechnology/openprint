CREATE TABLE Object_Payments (
	id	SERIAL,
	payment_id	INTEGER NOT NULL, FOREIGN KEY (payment_id) REFERENCES Payments (id),
	object_id	INTEGER NOT NULL,
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	amount		float,
	PRIMARY KEY (id)
);

CREATE INDEX object_payments_object_idx ON object_payments (object_type_id,object_id);
CREATE INDEX object_payments_payment_idx ON object_payments (payment_id);
