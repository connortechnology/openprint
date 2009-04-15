CREATE TABLE blacklist (
	ip			inet not null,
	count		integer,
	created_on	timestamp with time zone not null default now(),
	updated_on	timestamp with time zone not null default now(),
	PRIMARY KEY (ip)
);

