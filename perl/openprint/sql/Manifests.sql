CREATE TABLE Manifests (
	id	SERIAL,
	name	TEXT NOT NULL,
	received_on	timestamp with time zone NOT NULL default NOW(),
	updated_on	timestamp with time zone NOT NULL default NOW(),
	created_on	timestamp with time zone NOT NULL default NOW(),
	PRIMARY KEY (id)
);
ALTER TABLE PurchaseOrders ADD FOREIGN KEY (manifest_id) REFERENCES Manifests (id);
