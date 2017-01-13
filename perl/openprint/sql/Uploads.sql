DROP TABLE IF EXISTS Uploads;
CREATE TABLE Uploads (
	id	SERIAL,
	start	Timestamp with time zone NOT NULL,
	finished	timestamp	with time zone,
	size	integer NOT NULL,
	total	INTEGER NOT NULL,
	company_id	INTEGER, FOREIGN KEY (company_id) REFERENCES Companies (id),
	company		TEXT,
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES Users (id),
	file_path	TEXT,
	type		TEXT,
	complete	BOOLEAN,
	PRIMARY KEY (id)
);

create index uploads_company_id_idx on uploads (company_id);
create index uploads_start_idx on uploads (start);
