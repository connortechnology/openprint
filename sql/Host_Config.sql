CREATE TABLE Host_Config (
id SERIAL,
name	TEXT,
host_id INTEGER NOT NULL, FOREIGN KEY (host_id) REFERENCES Hosts(id),
data_json		JSON NOT NULL,
created_on TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
PRIMARY KEY(id)
);

CREATE INDEX host_config_host_id_idx on host_Config (host_id);
