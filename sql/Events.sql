
DROP TABLE IF EXISTS Events;
CREATE TABLE Events (
	id		SERIAL,
	name	TEXT,
	created_by	INTEGER NOT NULL, FOREIGN KEY (created_by) REFERENCES Users (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	deleted		BOOLEAN NOT NULL DEFAULT false,
	location_id	INTEGER, FOREIGN KEY (location_id) REFERENCES Locations (id),
	category_id	INTEGER, FOREIGN KEY (category_id) REFERENCES Event_Categories (id),
	info		TEXT,
	time_associated	BOOLEAN NOT NULL default false,
	starting_on	TIMESTAMP WITH TIME ZONE,
	ending_on	TIMESTAMP WITH TIME ZONE,
	asset_id	INTEGER, FOREIGN KEY (asset_id) REFERENCES Assets (id),
	album_id	INTEGER, FOREIGN KEY (album_id) REFERENCES Photo_Albums (id),
	published	BOOLEAN NOT NULL default false,
	template	BOOLEAN	NOT NULL default false,
	template_id	INTEGER, FOREIGN KEY (template_id) REFERENCES Events (id),
	PRIMARY KEY (id)
);
