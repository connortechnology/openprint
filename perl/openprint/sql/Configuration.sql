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

insert into Configuration values ('mail_db_name', '', 'text', 'Name of the database where the mail server accounts are stored.', 'Mail Server Settings');
insert into Configuration values ('mail_db_username', '', 'text', 'Username to access the database where the mail server accounts are stored.', 'Mail Server Settings');
insert into Configuration values ('mail_db_password', '', 'text', 'Password to access the database where the mail server accounts are stored.', 'Mail Server Settings');
insert into Configuration values ('mail_db_hostname', '', 'text', 'Hostname or ip address of the database server where the mail server accounts are stored.', 'Mail Server Settings');
insert into Configuration values ('mail_db_driver', 'Pg', 'text', 'Database driver to use:', 'Mail Server Settings');
insert into Configuration values ('mail_autoreply_domain', '', 'text', 'Domain for vacation autoreplies:', 'Mail Server Settings');
insert into Configuration values ('password_checks_min_length', '8', 'text', 'Minimum length a password must be.', 'Password Settings');
insert into Configuration values ('password_checks_alphanumeric', 'yes', 'yes/no', 'Make sure the password contains one of each from the following sets: a-z, A-Z and 0-9.', 'Password Settings');
