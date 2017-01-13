DROP TABLE IF EXISTS Host_Info;
CREATE TABLE Host_Info (
	id	SERIAL,
	host_id	INTEGER NOT NULL, FOREIGN KEY (host_id) REFERENCES Hosts (id),
	name	TEXT,
	value	TEXT,
	PRIMARY KEY (id)
);

CREATE INDEX host_info_host_idx ON host_info (host_id);
