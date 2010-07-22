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
	PRIMARY KEY (id)
);
