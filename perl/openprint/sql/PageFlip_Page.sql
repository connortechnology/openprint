
CREATE TABLE Pageflip_Page (
	id SERIAL,
	pageflip_id	INTEGER NOT NULL, FOREIGN KEY (pageflip_id) REFERENCES PageFlip (id),
	page		INTEGER NOT NULL,
	filename	TEXT,
	clip_box	box,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	updated_on	TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
	PRIMARY KEY (id)
);
