DROP	SEQUENCE	lngProjectIndex_seq;
CREATE	SEQUENCE	lngProjectIndex_seq;

DROP	SEQUENCE		DocketNumber_seq;
CREATE	SEQUENCE		DocketNumber_seq;
SELECT setval ('"docketnumber_seq"', 19000, true);

DROP	TABLE	tbl_Projects;

CREATE	TABLE	tbl_Projects	(
	Index			INT4	NOT NULL DEFAULT	nextval('lngProjectIndex_seq'),
	lngDocketNumber			INT4,
	strSessionID			char(10),
	CompanyIndex			INT4, FOREIGN KEY (CompanyIndex) REFERENCES Company (Index),
	UserIndex				INT4, FOREIGN KEY (UserIndex) REFERENCES Users (Index),
	strProjectReference		TEXT,
	strComments				TEXT,
	strDesign				TEXT,
	dtmCreationDate			timestamp with time zone,
	dtmLastModified			timestamp with time zone,
	intQuantity1			INT4,
	intQuantity2			INT4,
	intQuantity3			INT4,
	strStatus				TEXT,	/* Incomplete, Unordered, Ordered, Finished */
	strMode					TEXT,
	strPrograms				TEXT,
	strOtherPrograms		TEXT,
	type_id					INTEGER NOT NULL, FOREIGN KEY (type_id) REFERENCE ProjectTypes (id),
	price1					NUMERIC(10,2),
	price2					NUMERIC(10,2),
	price3					NUMERIC(10,2),
	externalrefnumber		TEXT,
	currency_id				INTEGER, FOREIGN KEY (currency_id) REFERENCES currencies (id),
	order_id				INTEGER, FOREIGN KEY (order_id) REFERENCES orders (index),
	due_date				date,
	rush					BOOLEAN default false,
	style_id				INTEGER, FOREIGN KEY (style_id) REFERENCES QuoteLevels (id),
	PRIMARY	KEY	(Index)
);

create index Project_created_on_idx on tbl_Projects (dtmcreationdate);
