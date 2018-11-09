CREATE TABLE Company_Profile_Fields (
	id	SERIAL,
	name	TEXT NOT NULL,
	required	boolean not null default false,
	description	TEXT,
	type		TEXT,
	values		TEXT[],
	sort		INTEGER,
	deleted		BOOLEAN NOT NULL DEFAULT FALSE,
	searchable	BOOLEAN NOT NULL DEFAULT FALSE,
	search_default	TEXT,
	match			TEXT,
	defaults	TEXT[],
	on_registration	BOOLEAN NOT NULL DEFAULT FALSE,
	viewable		BOOLEAN NOT NULL DEFAULT TRUE,
	PRIMARY KEY (id)
);
