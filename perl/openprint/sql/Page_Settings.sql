DROP TABLE IF EXISTS Page_Settings;

CREATE TABLE Page_Settings (
	id	SERIAL,
	url	TEXT UNIQUE,
	cacheable	TEXT,
	user_level	CHAR(1),
	PRIMARY KEY (id)
);
