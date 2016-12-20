CREATE TABLE Host_Interfaces (
	id	SERIAL,
	host_id	INTEGER NOT NULL, FOREIGN KEY (host_Id) REFERENCES HOsts(id),
	mac		macaddr,
	ip		inet,
	dhcp	BOOLEAN NOT NULL default false,
	comment	TEXT,
	connected_to  macaddr,
	monitor boolean not null default false,
	PRIMARY KEY (id)
);

CREATE INDEX Host_Interfaces_host_id_idx ON Host_Interfaces (host_id);
CREATE INDEX Host_Interfaces_ip_idx	ON Host_Interfaces (ip);
CREATE INDEX Host_Interfaces_mac_idx	ON Host_Interfaces (mac);
