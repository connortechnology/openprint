
DROP TABLE IF EXISTS Survey_Question_Categories;
DROP SEQUENCE IF EXISTS survey_question_category_id_seq;

CREATE TABLE Surveys (
	id			SERIAL,
	name		TEXT,
	description	TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	created_by	INTEGER NOT NULL, FOREIGN KEY (created_by) REFERENCES Users (id),
	PRIMARY KEY (id)
);

CREATE SEQUENCE survey_question_category_id_seq;

CREATE TABLE survey_question_categories (
	id		SERIAL,
	name	TEXT NOT NULL,
	sorting	INTEGER,
	PRIMARY KEY (id)
);
