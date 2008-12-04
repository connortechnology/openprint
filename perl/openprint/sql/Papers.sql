/* 
*/

DROP SEQUENCE IF EXISTS PaperName_id_seq;
CREATE SEQUENCE PaperName_id_seq;

DROP TABLE IF EXISTS PaperNames;
CREATE TABLE PaperNames (
	id 	INTEGER NOT NULL default nextval('PaperName_id_seq'),
	shortname	TEXT NOT NULL,
	longname	TEXT NOT NULL,
	PRIMARY KEY (id)
);

DROP SEQUENCE IF EXISTS PaperFinish_id_seq;
CREATE SEQUENCE PaperFinish_id_seq;

DROP TABLE IF EXISTS PaperFinishes;
CREATE TABLE PaperFinishes (
		id  INTEGER NOT NULL default nextval('PaperFinish_id_seq'),
		shortname   TEXT NOT NULL,
		longname    TEXT NOT NULL,
		PRIMARY KEY (id)
		);

DROP SEQUENCE IF EXISTS PaperColour_id_seq;
CREATE SEQUENCE PaperColour_id_seq;

DROP TABLE IF EXISTS PaperColours;
CREATE TABLE PaperColours (
		id  INTEGER NOT NULL default nextval('PaperColour_id_seq'),
		shortname   TEXT NOT NULL,
		longname    TEXT NOT NULL,
		PRIMARY KEY (id)
		);

DROP SEQUENCE IF EXISTS PaperWeight_id_seq;
CREATE SEQUENCE PaperWeight_id_seq;

DROP TABLE IF EXISTS PaperWeights;
CREATE TABLE PaperWeights (
		id  INTEGER NOT NULL default nextval('PaperWeight_id_seq'),
		shortname   TEXT NOT NULL,
		longname    TEXT NOT NULL,
		PRIMARY KEY (id)
		);

DROP SEQUENCE IF EXISTS PaperQuality_id_seq;
CREATE SEQUENCE PaperQuality_id_seq;
DROP TABLE IF EXISTS PaperQualities;
CREATE TABLE PaperQualities (
		id  INTEGER NOT NULL default nextval('PaperQuality_id_seq'),
		shortname   TEXT NOT NULL,
		longname    TEXT NOT NULL,
		PRIMARY KEY (id)
);

DROP SEQUENCE IF EXISTS StockPurposes_id_seq;
CREATE SEQUENCE StockPurposes_id_seq;
DROP TABLE IF EXISTS StockPurposes;
CREATE TABLE StockPurposes (
	id  INTEGER NOT NULL default nextval('StockPurposes_id_seq'),
	name   TEXT NOT NULL,
	PRIMARY KEY (id)
);


DROP SEQUENCE IF EXISTS Paper_id_seq;
CREATE SEQUENCE Paper_id_seq;

DROP TABLE IF EXISTS Papers;

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
	purpose_id		integer, foreign key (purpose_id) REFERENCES stockpurposes (id),
	PRIMARY KEY (id)
);
