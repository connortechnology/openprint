
CREATE TABLE survey_responses (
	survey_id	INTEGER NOT NULL, FOREIGN KEY (survey_id) REFERENCES Surveys (id),
	company_id	INTEGER, FOREIGN KEY (company_id) REFERENCES Companies (id),
	question_id	INTEGER NOT NULL, FOREIGN KEY (question_id) REFERENCES Survey_Questions (id),
	user_id		INTEGER NOT NULL, FOREIGN KEY (user_id) REFERENCES Users (id),
	answer_id	INTEGER[],
	answer		TEXT,
	created_on	TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT NOW(),
	public		BOOLEAN,
	PRIMARY KEY (question_id,user_id)
);

