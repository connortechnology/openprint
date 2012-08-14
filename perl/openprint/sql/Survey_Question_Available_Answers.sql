
CREATE TABLE Survey_Question_Available_Answers (
	question_id	INTEGER NOT NULL, FOREIGN KEY (question_id) REFERENCES Survey_Questions (id),
	answer_id	INTEGER NOT NULL, FOREIGN KEY (answer_id) REFERENCES Survey_Answers (id),
	sorting		INTEGER,
	PRIMARY KEY (question_id,answer_id)
);

