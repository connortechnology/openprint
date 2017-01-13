DROP TABLE IF EXISTS PAR;
CREATE TABLE PAR_Areas (
    id  SERIAL NOT NULL,
    name    TEXT NOT NULL,
    assignee_id INTEGER, FOREIGN KEY (assignee_id) REFERENCES Users (id),
    deleted     BOOLEAN,
    sorting     INTEGER,
    PRIMARY KEY (id)
);
CREATE TABLE PAR_Reasons (
    id  SERIAL NOT NULL,
    area_id INTEGER NOT NULL, FOREIGN KEY (area_id) REFERENCES PAR_Areas (id),
    name    TEXT NOT NULL,
    deleted     BOOLEAN,
    sorting     INTEGER,
    PRIMARY KEY (id)
);

CREATE TABLE PAR (
	id serial NOT NULL,
	issued_to_id	INTEGER NOT NULL, FOREIGN KEY (issued_to_id) REFERENCES Users (id),
	issued_on	date not null default NOW(),
	issued_by_id	INTEGER NOT NULL, FOREIGN KEY (issued_by_id) REFERENCES Users (id),
	reply_by	date not null default NOW(),
	problem		text,
	cause		text,
	action		text,
	effectiveness		text,
	part1_user_id	INTEGER, FOREIGN KEY (part1_user_id) REFERENCES Users (id),
	part1_signed_on	date,
	part2_user_id	INTEGER, FOREIGN KEY (part2_user_id) REFERENCES Users (id),
	part2_signed_on	date,
	part3_user_id	INTEGER, FOREIGN KEY (part3_user_id) REFERENCES Users (id),
	part3_signed_on	date,
	part4_user_id	INTEGER, FOREIGN KEY (part3_user_id) REFERENCES Users (id),
	part4_signed_on	date,
	created_on	timestamp with time zone NOT NULL default NOW(),
	updated_on	timestamp with time zone NOT NULL default NOW(),
	deleted		boolean default false,
	area_id		INTEGER NOT NULL,FOREIGN KEY (area_id) REFERENCES PAR_Areas (id),
	reason_id	INTEGER NOT NULL,FOREIGN KEY (reason_id) REFERENCES PAR_Reasons (id),
	PRIMARY KEY (id)
);
