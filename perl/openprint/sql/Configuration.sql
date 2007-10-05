DROP TABLE Configuration;

CREATE TABLE Configuration (
    Name		TEXT NOT NULL,
    Value		TEXT,
	Type		TEXT,
	Description	TEXT,
	Category	TEXT,
	PRIMARY KEY (Name)
);

insert into Configuration values ('UsesCookies','true', 'radio' );
insert into Configuration values ('cookie_issue_URIs','.*index\.html', 'text' );
insert into Configuration values ('no_cookie_URIs','/error/.*\.html', 'text' );
insert into Configuration values ('companyname','TopKnotch Prep & Print', 'text' );

