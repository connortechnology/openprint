DROP TABLE IF EXISTS hosts;
CREATE TABLE hosts (
	id	SERIAL,
	ip	inet NOT NULL,
	mac	macaddr,
	hostname	text,
	PRIMARY KEY (id)
);
