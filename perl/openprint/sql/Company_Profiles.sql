DROP TABLE IF EXISTS Company_Profiles;

CREATE TABLE Company_Profiles (
	company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Companies (id),
	field_id	INTEGER NOT NULL, FOREIGN KEY (field_id) REFERENCES Company_Profile_Fields (id),
	value		TEXT,
	PRIMARY KEY (company_id, field_id)
);
