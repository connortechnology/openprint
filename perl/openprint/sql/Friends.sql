DROP TABLE IF EXISTS Friends ;

CREATE TABLE Friends (
	user_id INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES USers (id),
	friends	INTEGER[],
	PRIMARY KEY (user_id)
);
