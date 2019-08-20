CREATE TABLE License_Hosts (
	license_id	INTEGER NOT NULL, FOREIGN KEY (license_id) REFERENCES Licenses (id),
	host_id		INTEGER NOT NULL, FOREIGN KEY (host_id) REFERENCES Hosts (id),
	comment		TEXT,
	created_on 	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	PRIMARY KEY (host_id,license_id)
);
