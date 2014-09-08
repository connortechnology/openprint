CREATE TABLE Host_Interfaces (
	host_id	INTEGER NOT NULL, FOREIGN KEY (host_Id) REFERENCES HOsts(id),
	mac		macaddr NOT NULL,
	ip		inet,
	dhcp	BOOLEAN
);

CREATE INDEX Host_Interfaces_host_id_idx ON Host_Interfaces (host_id);

