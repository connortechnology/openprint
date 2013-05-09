/* 
*/

CREATE SEQUENCE PaperName_id_seq;

CREATE TABLE PaperNames (
	id 	INTEGER NOT NULL default nextval('PaperName_id_seq'),
	shortname	TEXT NOT NULL,
	longname	TEXT NOT NULL,
	PRIMARY KEY (id)
);

CREATE SEQUENCE PaperFinish_id_seq;

CREATE TABLE PaperFinishes (
		id  INTEGER NOT NULL default nextval('PaperFinish_id_seq'),
		shortname   TEXT NOT NULL,
		longname    TEXT NOT NULL,
		PRIMARY KEY (id)
		);

CREATE SEQUENCE PaperColour_id_seq;

CREATE TABLE PaperColours (
		id  INTEGER NOT NULL default nextval('PaperColour_id_seq'),
		shortname   TEXT NOT NULL,
		longname    TEXT NOT NULL,
		PRIMARY KEY (id)
		);

CREATE SEQUENCE PaperWeight_id_seq;

CREATE TABLE PaperWeights (
		id  INTEGER NOT NULL default nextval('PaperWeight_id_seq'),
		shortname   TEXT NOT NULL,
		longname    TEXT NOT NULL,
		PRIMARY KEY (id)
		);

CREATE SEQUENCE PaperQuality_id_seq;
CREATE TABLE PaperQualities (
		id  INTEGER NOT NULL default nextval('PaperQuality_id_seq'),
		shortname   TEXT NOT NULL,
		longname    TEXT NOT NULL,
		PRIMARY KEY (id)
);

CREATE TABLE StockPurposes (
	id  SERIAL,
	name   TEXT NOT NULL,
	PRIMARY KEY (id)
);


CREATE SEQUENCE Paper_id_seq;

CREATE TABLE Papers (
	id			INTEGER NOT NULL default nextval('Paper_id_seq'),
	owner_id	INTEGER NOT NULL, FOREIGN KEY (owner_id) REFERENCES Companies (id),
	manufacturer_id	INTEGER NOT NULL, FOREIGN KEY (manufacturer_id) REFERENCES Manufacturers (id),
	name_id		INTEGER NOT NULL, FOREIGN KEY (name_id) REFERENCES PaperNames (id),
	finish_id	INTEGER NOT NULL, FOREIGN KEY (finish_id) REFERENCES PaperFinishes (id),
	colour_id	INTEGER NOT NULL, FOREIGN KEY (colour_id) REFERENCES PaperColours (id),
	weight_id	INTEGER NOT NULL, FOREIGN KEY (weight_id) REFERENCES PaperWeights (id),
	quality_id	INTEGER NOT NULL, FOREIGN KEY (quality_id) REFERENCES PaperQualities (id),
	cuttable	boolean NOT NULL default true,
	doublesided	boolean	NOT NULL default true,
	perfecting	boolean NOT NULL default false,
	taxexempt1	boolean NOT NULL default false,
	taxexempt2	boolean NOT NULL default false,
	multipart	boolean NOT NULL default false,
	score_required	boolean NOT NULL default false,
	die_score_required	BOOLEAN NOT NULL default false,
	calliper	NUMERIC(10,4),
	width		float,
	height		float,
	mweight		float,
	gsm			float,
	basis_width	float,
	basis_height	float,
	blade_cleaning	boolean,
	grain_direction	text,
	grade			integer,	
	fsc_code		text,
	message			text,
	parts			integer,
	in_stock		INTEGER,
	allocated		INTEGER,
	user_type		char(1),
	PRIMARY KEY (id)
);
