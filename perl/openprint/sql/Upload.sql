DROP SEQUENCE Upload_id_seq;
CREATE SEQUENCE Upload_id_seq;

DROP TABLE Uploads;
CREATE TABLE Uploads (
	id	INTEGER NOT NULL,
	start	Timestamp with time zone NOT NULL,
	finished	timestamp	with time zone,
	size	integer NOT NULL,
	total	INTEGER NOT NULL,
	company_id	INTEGER, FOREIGN KEY (company_id) REFERENCES Company (index),
	company		TEXT,
	user_id		INTEGER, FOREIGN KEY (user_id) REFERENCES Users (index),
	file_path	TEXT,
	PRIMARY KEY (id)
);
