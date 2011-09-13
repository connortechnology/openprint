DROP TABLE IF EXISTS hosts;
CREATE TABLE hosts (
	id			SERIAL,
	ip			inet,
	mac	macaddr[],
	hostname	text,
	blacklisted	boolean not null default false,
	whitelisted	boolean not null default false,
	monitored	boolean not null default false,
	description text,
	dhcp		boolean not null default false,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	count		INTEGER,
	deleted		BOOLEAN NOT NULL DEFAULT FALSE,
	online		BOOLEAN,
	PRIMARY KEY (id)
);
CREATE INDEX hosts_ip_idx on Hosts (ip);
