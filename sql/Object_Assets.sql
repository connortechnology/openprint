
DROP TABLE IF EXISTS Object_Assets;
CREATE TABLE Object_Assets (
	object_type_id	INTEGER NOT NULL, FOREIGN KEY (object_type_id) REFERENCES Object_Types (id),
	object_id	INTEGER,
	asset_id	INTEGER, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	PRIMARY KEY (object_type_id,object_id,asset_id)
);

