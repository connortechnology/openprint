DROP TABLE IF EXISTS Page_Settings;

CREATE TABLE Page_Settings (
	id	SERIAL,
	url	TEXT UNIQUE,
	cacheable	TEXT,
	user_level	CHAR(1),
	description	TEXT,
	keywords	TEXT,
	PRIMARY KEY (id)
);

INSERT INTO Page_Settings (url,user_level) values ('/employee', 'E' );
INSERT INTO Page_Settings (url,user_level) values ('/employee/account', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/employee/account/profile.html', 'E' );
INSERT INTO Page_Settings (url,user_level) values ('/administrator', 'A' );
INSERT INTO Page_Settings (url,user_level) values ('/administrator/account', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/', 'C' );
INSERT INTO Page_Settings (url,user_level) values ('/account/login.html', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/account/logout.html', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/account/registration.html', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/account/credit_application.html', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/account/reseller_application.html', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/account/confirmation_forgotten_password.html', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/account/forgotten_password.html', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/support', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/main/company', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/main/services', NULL );
INSERT INTO Page_Settings (url,user_level) values ('/index.html', NULL );
