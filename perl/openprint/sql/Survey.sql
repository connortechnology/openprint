
DROP TABLE IF EXISTS Survey_Question_Available_Answers;

DROP TABLE IF EXISTS Survey_Responses;

DROP TABLE IF EXISTS Survey_Answers;
DROP SEQUENCE IF EXISTS survey_answer_id_seq;
DROP TABLE IF EXISTS Survey_Questions;
DROP SEQUENCE IF EXISTS survey_question_id_seq;

DROP TABLE IF EXISTS Survey_Question_Categories;
DROP SEQUENCE IF EXISTS survey_question_category_id_seq;

DROP TABLE IF EXISTS Surveys;
DROP SEQUENCE IF EXISTS survey_id_seq;

CREATE SEQUENCE survey_id_seq;
CREATE TABLE Surveys (
	id	INTEGER NOT NULL default nextval('survey_id_seq'),
	name	TEXT,
	PRIMARY KEY (id)
);

CREATE SEQUENCE survey_question_category_id_seq;

CREATE TABLE Survey_Question_Categories (
	id		INTEGER NOT NULL default nextval('survey_question_category_id_seq'),
	name	TEXT NOT NULL,
	PRIMARY KEY (id)
);

CREATE SEQUENCE survey_question_id_seq;
CREATE TABLE Survey_Questions (
	id			INTEGER NOT NULL default nextval('survey_question_id_seq'),
	survey_id	INTEGER NOT NULL, FOREIGN KEY (survey_id) REFERENCES Surveys (id),
	category_id	INTEGER NOT NULL, FOREIGN KEY (category_id) REFERENCES Survey_Question_Categories (id),
	text		TEXT NOT NULL,
	PRIMARY KEY (id)
);

CREATE TABLE Survey_Responses (
	survey_id	INTEGER NOT NULL, FOREIGN KEY (survey_id) REFERENCES Surveys (id),
	company_id	INTEGER NOT NULL, FOREIGN KEY (company_id) REFERENCES Company (Index),
	question_id	INTEGER NOT NULL, FOREIGN KEY (question_id) REFERENCES Survey_Questions (id),
	answer		TEXT NOT NULL
);

CREATE SEQUENCE Survey_Answer_ID_seq;
CREATE TABLE Survey_Answers (
	id			INTEGER NOT NULL default nextval('Survey_Answer_ID_seq'),

	survey_id	INTEGER NOT NULL, FOREIGN KEY (survey_id) REFERENCES Surveys (id),
	text		text	NOT NULL,
	sorting		INTEGER,
	PRIMARY KEY (id)
);

CREATE TABLE Survey_Question_Available_Answers (
	question_id	INTEGER NOT NULL, FOREIGN KEY (question_id) REFERENCES Survey_Questions (id),
	answer_id	INTEGER NOT NULL, FOREIGN KEY (answer_id) REFERENCES Survey_Answers (id)
);

