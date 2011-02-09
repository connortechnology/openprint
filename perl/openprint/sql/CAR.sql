DROP TABLE IF EXISTS CAR;
CREATE TABLE CAR_Areas (
	id	SERIAL NOT NULL,
	name	TEXT NOT NULL,
	assignee_id	INTEGER, FOREIGN KEY (assignee_id) REFERENCES Users (id),
	deleted		BOOLEAN,
	sorting		INTEGER,
	PRIMARY KEY (id)
);
CREATE TABLE CAR_Reasons (
	id	SERIAL NOT NULL,
	area_id	INTEGER NOT NULL, FOREIGN KEY (area_id) REFERENCES CAR_Areas (id),
	name	TEXT NOT NULL,
	deleted		BOOLEAN,
	sorting		INTEGER,
	PRIMARY KEY (id)
);
CREATE TABLE CAR (
	id serial NOT NULL,
	issued_to_id	INTEGER, FOREIGN KEY (issued_to_id) REFERENCES Users (id),
	issued_on	date not null default NOW(),
	issued_by_id	INTEGER NOT NULL, FOREIGN KEY (issued_by_id) REFERENCES Users (id),
	reply_by	date not null default NOW(),
	docket			INTEGER,
	company_id		INTEGER, FOREIGN KEY (company_id) REFERENCES Companies (Id),
	printed_on		date,
	identified_by	text,
	problem		text,
	cause		text,
	action		text,
	effectiveness		text,
	presses		text,
	part1_user_id	INTEGER, FOREIGN KEY (part1_user_id) REFERENCES Users (id),
	part1_signed_on	date,
	part2_user_id	INTEGER, FOREIGN KEY (part2_user_id) REFERENCES Users (id),
	part2_signed_on	date,
	part3_user_id	INTEGER, FOREIGN KEY (part3_user_id) REFERENCES Users (id),
	part3_signed_on	date,
	part4_user_id	INTEGER, FOREIGN KEY (part3_user_id) REFERENCES Users (id),
	part4_signed_on	date,
	reprint			text,
	reprint_approval	text,
	reprint_charge	text,
	reprint_quantity	INTEGER,
	reprint_value		NUMERIC(10,2),
	artwork			text,
	reprint_on	date,
	approved_by_id	INTEGER, FOREIGN KEY (approved_by_id) REFERENCES Users (id),
	approved_on		date,

	created_on	timestamp with time zone NOT NULL default NOW(),
	updated_on	timestamp with time zone NOT NULL default NOW(),
	deleted		boolean default false,
	area_id		INTEGER, FOREIGN KEY (area_id) REFERENCES Car_Areas (id),
	reason_id		INTEGER, FOREIGN KEY (reason_id) REFERENCES Car_Reasons (id),
	PRIMARY KEY (id)
);

