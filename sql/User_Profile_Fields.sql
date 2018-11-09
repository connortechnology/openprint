DROP TABLE IF EXISTS User_Profile_Fields;
CREATE TABLE User_Profile_Fields (
	id	SERIAL,
	name	TEXT NOT NULL,
	required	boolean not null default false,
	description	TEXT,
	type		TEXT,
	values		TEXT[],
	defaults	TEXT[],
	sort		INTEGER,
	deleted		BOOLEAN NOT NULL DEFAULT FALSE,
	searchable	BOOLEAN NOT NULL DEFAULT FALSE,
	search_default	TEXT,	
	match		TEXT,
	on_registration	BOOLEAN,
	viewable	BOOLEAN,
	PRIMARY KEY (id)
);
