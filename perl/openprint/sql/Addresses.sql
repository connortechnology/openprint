CREATE TABLE Addresses (
	id					SERIAL,
	company_id			INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	location_id			INTEGER NOT NULL, FOREIGN KEY (location_id) REFERENCES Locations (id),
	user_id				INTEGER, FOREIGN KEY (user_id) REFERENCES Users (id),
	name				TEXT,
	notes				TEXT,
	created_on			TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	PRIMARY KEY (id)
);

/*
 CREATE INDEX Addresses_idx ON Addresses (company_id, user_id); 
*/
