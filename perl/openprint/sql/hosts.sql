DROP TABLE IF EXISTS hosts;
CREATE TABLE hosts (
	id			SERIAL,
	ip			inet,
	mac	macaddr[],
	hostname	text,
	block	boolean not null default false,
	monitor	boolean not null default false,
	description text,
	PRIMARY KEY (id)
);
CREATE INDEX hosts_ip_idx on Hosts (ip);
