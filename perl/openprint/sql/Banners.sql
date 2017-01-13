DROP TABLE IF EXISTS Banners;
CREATE TABLE Banners (
	id	SERIAL,
	supplier_id	INTEGER, FOREIGN KEY (supplier_id) REFERENCES companies (id),
	name	TEXT,
	url		TEXT,
	asset_id	INTEGER, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	PRIMARY KEY (id)
);
