DROP TABLE IF EXISTS Configuration;

CREATE TABLE Configuration (
    Name		TEXT NOT NULL,
    Value		TEXT,
	Type		TEXT,
	Description	TEXT,
	Category	TEXT,
	PRIMARY KEY (Name)
);


insert into Configuration values ('mail_db_name', '', 'text', 'Name of the database where the mail server accounts are stored.', 'Mail Server Settings');
insert into Configuration values ('mail_db_username', '', 'text', 'Username to access the database where the mail server accounts are stored.', 'Mail Server Settings');
insert into Configuration values ('mail_db_password', '', 'text', 'Password to access the database where the mail server accounts are stored.', 'Mail Server Settings');
insert into Configuration values ('mail_db_hostname', '', 'text', 'Hostname or ip address of the database server where the mail server accounts are stored.', 'Mail Server Settings');
insert into Configuration values ('mail_db_driver', 'Pg', 'text', 'Database driver to use:', 'Mail Server Settings');
insert into Configuration values ('mail_autoreply_domain', '', 'text', 'Domain for vacation autoreplies:', 'Mail Server Settings');
insert into Configuration values ('public_URIs', '/,/index.html,/account/login.html,/account/registration.html', 'text', 'Comma separated list of pages on the site that can be read without logging in','Miscellaneous Settings' );
insert into Configuration values ('NewFirstUserAccountActivation', 'N', 'yes/no', 'Whether to automatically activate the first user in a company when they register.','Miscellaneous Settings' );
insert into Configuration values ('NewNonFirstUserAccountActivation', 'N', 'yes/no', 'Whether to automatically activate any subsequent users in a company when they register.','Miscellaneous Settings' );
insert into Configuration values ('NewCustomerAccountActivation', 'N', 'yes/no', 'Whether to automatically activate new companies when they register.','Miscellaneous Settings' );
insert into Configuration values ('Mail Server', 'localhost', 'text', '','Miscellaneous Settings' );
insert into Configuration values ('startYear', '2011', 'text', 'The year the website went up.  Used to limit the # of years displayed in date fields','Miscellaneous Settings' );
insert into Configuration values ('password_checks_min_length', '8', 'text', 'Minimum length a password must be.', 'Password Settings');
insert into Configuration values ('password_checks_alphanumeric', 'yes', 'yes/no', 'Make sure the password contains one of each from the following sets: a-z, A-Z and 0-9.', 'Password Settings');
