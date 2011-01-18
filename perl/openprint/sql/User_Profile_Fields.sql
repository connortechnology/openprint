DROP TABLE IF EXISTS User_Profile_Fields;
CREATE TABLE User_Profile_Fields (
	id	SERIAL,
	name	TEXT NOT NULL,
	required	boolean not null default false,
	description	TEXT,
	type		TEXT,
	values		TEXT[],
	sort		INTEGER,
	PRIMARY KEY (id)
);
