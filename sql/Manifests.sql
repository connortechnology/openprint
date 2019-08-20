CREATE TABLE Manifests (
	id	SERIAL,
	name	TEXT NOT NULL,
	received_on	timestamp with time zone NOT NULL default NOW(),
	updated_on	timestamp with time zone NOT NULL default NOW(),
	created_on	timestamp with time zone NOT NULL default NOW(),
	deleted	BOOLEAN NOT NULL default false,
	PRIMARY KEY (id)
);
ALTER TABLE PurchaseOrders ADD FOREIGN KEY (manifest_id) REFERENCES Manifests (id);
CREATE INDEX Manifests_received_on_idx on Manifests (received_on);
CREATE INDEX Manifests_created_on_idx on Manifests (created_on);
CREATE INDEX Manifests_name_idx on Manifests (name);

