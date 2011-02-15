DROP TABLE IF EXISTS Company_Profile_Fields;
CREATE TABLE Company_Profile_Fields (
	id	SERIAL,
	name	TEXT NOT NULL,
	required	boolean not null default false,
	description	TEXT,
	type		TEXT,
	values		TEXT[],
	sort		INTEGER,
	PRIMARY KEY (id)
);
