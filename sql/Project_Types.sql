
CREATE TABLE Project_Types (
	id		SERIAL NOT NULL,
	name			TEXT,
	description		TEXT,
	URL				TEXT,
	Sorting			INT4,
	category_id		INTEGER, FOREIGN KEY (category_id) REFERENCES ProjectType_Categories (id),
	PRIMARY KEY (Id)
);


create index ProjectTypes_Name_idx on Project_Types (name);
