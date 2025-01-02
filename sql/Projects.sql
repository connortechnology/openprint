DROP	SEQUENCE	IF EXISTS lngProjectIndex_seq;
CREATE	SEQUENCE	lngProjectIndex_seq;

DROP	SEQUENCE		IF EXISTS DocketNumber_seq;
CREATE	SEQUENCE		DocketNumber_seq;

DROP	TABLE	IF EXISTS Projects;

CREATE	TABLE	Projects	(
	id			INTEGER	NOT NULL DEFAULT	nextval('lngProjectIndex_seq'),
	lngDocketNumber			INTEGER,
	company_id			INTEGER, FOREIGN KEY (company_id) REFERENCES Companies (Id),
	user_id				INTEGER, FOREIGN KEY (user_id) REFERENCES Users (Id),
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
	type_id					INTEGER, FOREIGN KEY (type_id) REFERENCES Project_Types (id),
	price1					NUMERIC(10,2),
	price2					NUMERIC(10,2),
	price3					NUMERIC(10,2),
	externalrefnumber		TEXT,
	currency_id				INTEGER, FOREIGN KEY (currency_id) REFERENCES currencies (id),
	order_id				INTEGER, FOREIGN KEY (order_id) REFERENCES orders (id),
	due_date				date,
	rush					BOOLEAN default false,
	style_id				INTEGER, FOREIGN KEY (style_id) REFERENCES QuoteLevels (id),
	summary					TEXT,
	markup					float,
	reprint					char(1) default 'N',
	reprint_reason				TEXT,
	reprint_description		TEXT,
	predefined				BOOLEAN NOT NULL DEFAULT FALSE,
	priority				INTEGER,
	production_comments		TEXT,
	PRIMARY	KEY	(id)
);

create index Project_created_on_idx on Projects (dtmcreationdate, company_id);
