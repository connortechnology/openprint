
CREATE TABLE survey_questions (
	id			SERIAL,
	survey_id	INTEGER, FOREIGN KEY (survey_id) REFERENCES Surveys (id),
	category_id	INTEGER, FOREIGN KEY (category_id) REFERENCES Survey_Question_Categories (id),
	text		TEXT,
	type		TEXT,
	sorting		INTEGER,
	alignment	BOOLEAN,
	PRIMARY KEY (id)
);
