DROP TABLE IF EXISTS Assets;
DROP TABLE IF EXISTS Asset_Types;

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
	PRIMARY KEY (id)
);
alter table Users add foreign key (asset_Id) REFERENCES assets (Id);
