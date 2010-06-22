DROP TABLE IF EXISTS hosts;
CREATE TABLE hosts (
	id	SERIAL,
	ip	inet NOT NULL,
	mac	macaddr[],
	hostname	text,
	block	boolean not null default false,
	monitor	boolean not null default false,
	description text,
	PRIMARY KEY (id)
);
