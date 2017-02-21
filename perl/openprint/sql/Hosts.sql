DROP TABLE IF EXISTS hosts;
CREATE TABLE hosts (
	id			SERIAL,
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
	state_changed_on	INTEGER,
	offline_seconds		INTEGER,
	notified			BOOLEAN NOT NULL DEFAULT FALSE,
	notify_frequency	INTEGER,
	location_id			INTEGER, FOREIGN KEY (location_id) REFERENCES Locations (id),
	PRIMARY KEY (id)
);
