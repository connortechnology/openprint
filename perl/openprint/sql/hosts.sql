DROP TABLE IF EXISTS hosts;
CREATE TABLE hosts (
	id	SERIAL,
	ip	inet NOT NULL,
	mac	macaddr,
	hostname	text,
	PRIMARY KEY (id)
);
CREATE INDEX hosts_ip_idx on Hosts (ip);
