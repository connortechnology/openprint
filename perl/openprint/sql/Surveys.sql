
DROP TABLE IF EXISTS Survey_Question_Available_Answers;

DROP TABLE IF EXISTS Survey_Responses;

DROP TABLE IF EXISTS survey_answers;
DROP SEQUENCE IF EXISTS survey_answer_id_seq;
DROP TABLE IF EXISTS survey_questions;
DROP SEQUENCE IF EXISTS survey_questions_id_seq;

DROP TABLE IF EXISTS Survey_Question_Categories;
DROP SEQUENCE IF EXISTS survey_question_category_id_seq;

DROP TABLE IF EXISTS surveys;

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
	PRIMARY KEY (id)
);

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

CREATE TABLE Survey_Answers (
	id			SERIAL,
	text		text,
	sorting		INTEGER,
	PRIMARY KEY (id)
);

CREATE TABLE survey_responses (
	survey_id	INTEGER NOT NULL, FOREIGN KEY (survey_id) REFERENCES Surveys (id),
	company_id	INTEGER, FOREIGN KEY (company_id) REFERENCES Companies (id),
	question_id	INTEGER NOT NULL, FOREIGN KEY (question_id) REFERENCES Survey_Questions (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	answer_id	INTEGER, FOREIGN KEY (answer_id) REFERENCES Survey_Answers (id),
	answer		TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	public		BOOLEAN,
	PRIMARY KEY (id)
);
CREATE INDEX Survey_Responses_idx on Survey_Responses (question_id,user_id);


CREATE TABLE Survey_Question_Available_Answers (
	question_id	INTEGER NOT NULL, FOREIGN KEY (question_id) REFERENCES Survey_Questions (id),
	answer_id	INTEGER NOT NULL, FOREIGN KEY (answer_id) REFERENCES Survey_Answers (id),
	sorting		INTEGER,
	PRIMARY KEY (question_id,answer_id)
);

