DROP TABLE IF EXISTS whitelist;
CREATE TABLE whitelist (
	ip			inet not null,
	created_on	timestamp with time zone not null default now(),
	PRIMARY KEY (ip)
);

