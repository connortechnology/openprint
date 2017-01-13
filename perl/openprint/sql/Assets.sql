
CREATE TABLE Asset_Types (
	id SERIAL,
	name text,
	PRIMARY KEY (id)
);

CREATE TABLE Assets (
	id SERIAL,
	company_id	INTEGER, FOREIGN KEY (company_id) REFERENCES Companies (id),
	created_by	INTEGER, FOREIGN KEY (created_by) REFERENCES Users (id),
	name	text,
	description	text,
	filename	text,
	data	bytea,
	type_id	INTEGER, FOREIGN KEY (type_id) REFERENCES Asset_Types (id),
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	md5		char(32),
	deleted	BOOLEAN NOT NULL default false,
	optimised	BOOLEAN NOT NULL DEFAULT FALSE,
	layout		TEXT,
	width		INTEGER,
	height		INTEGER,
	source		TEXT,
	PRIMARY KEY (id)
);
alter table Users add foreign key (asset_id) REFERENCES assets (id);
