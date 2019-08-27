
DROP   TABLE IF EXISTS User_Service_Defaults;

CREATE TABLE User_Service_Defaults ( 
	id				SERIAL NOT NULL,
	user_id			INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	servicetype_id	INTEGER, FOREIGN KEY (servicetype_id) REFERENCES Service_Types (id),
	name			TEXT,
	value			TEXT,
	PRIMARY KEY( id )
);
