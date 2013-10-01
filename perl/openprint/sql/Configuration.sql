/*DROP TABLE IF EXISTS Configuration;*/

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
insert into Configuration values ('NewFirstUserAccountActivation', 'N', 'yes/no', 'Whether to automatically activate the first user in a company when they register.','Miscellaneous Settings' );
insert into Configuration values ('NewNonFirstUserAccountActivation', 'N', 'yes/no', 'Whether to automatically activate any subsequent users in a company when they register.','Miscellaneous Settings' );
insert into Configuration values ('NewCustomerAccountActivation', 'N', 'yes/no', 'Whether to automatically activate new companies when they register.','Miscellaneous Settings' );
insert into Configuration values ('Mail Server', 'localhost', 'text', '','Miscellaneous Settings' );
insert into Configuration values ('startYear', '2012', 'text', 'The year the website went up.  Used to limit the # of years displayed in date fields','Miscellaneous Settings' );
insert into Configuration values ('password_checks_min_length', '6', 'text', 'Minimum length a password must be.', 'Password Settings');
insert into Configuration values ('password_checks_max_length', '0', 'text', 'Maximum length a password must be.', 'Password Settings');
insert into Configuration values ('password_checks_uppercase', 'yes', 'yes/no', 'Password must have uppercase characters.', 'Password Settings');
insert into Configuration values ('password_checks_lowercase', 'yes', 'yes/no', 'Password must have lowercase characters.', 'Password Settings');
insert into Configuration values ('password_checks_numbers', 'yes', 'yes/no', 'Password must have numbers.', 'Password Settings');
insert into Configuration values ('password_checks_punctuation', 'yes', 'yes/no', 'Password must have punctuation.', 'Password Settings');
insert into Configuration values ('password_checks_min_score', '10', 'text', 'Password must have a minimum score.', 'Password Settings');
insert into Configuration values ('Require Unique Company', 'N', 'yes/no', 'Require a unique companyname.', 'Miscellaneous Settings');
insert into Configuration values ('SimpleButtons', 'Y', 'yes/no', 'When true, a button will just use an anchor tag, without internal left right and center pieces.', 'Miscellaneous Settings');

INSERT INTO configuration VALUES ('RegistrationCaptchaLength', '3', 'text', 'Number of characters in the CAPTCHA on the registration page.', 'Captcha Settings');
INSERT INTO configuration VALUES ('UnitPriceFormat', '%.2f', 'text', 'Format String for unit prices.', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('Cached Objects', '', 'text', NULL, NULL);
INSERT INTO configuration VALUES ('AdministratorEmail', '"Isaac Connor" <iconnor@connortechnology.com>', 'text', 'Email address of the person in charge of the website.', 'Email Notifications');
INSERT INTO configuration VALUES ('AccountingEmail', '"Isaac Connor" <iconnor@connortechnology.com>', 'text', 'Email address of the person in charge of accounting.', 'Email Notifications');
INSERT INTO configuration VALUES ('QuotingEmail', '"Isaac Connor" <iconnor@connortechnology.com>', 'text', 'Email address to send quotes to.', 'Email Notifications');
INSERT INTO configuration VALUES ('CreditApplicationEmail', '"Isaac Connor" <iconnor@connortechnology.com>', 'text', 'Email address to send new credit applications to.', 'Email Notifications');
INSERT INTO configuration VALUES ('ResellerApplicationEmail', '"Isaac Connor" <iconnor@connortechnology.com>', 'text', 'Email address to send new reseller applications to.', 'Email Notifications');
INSERT INTO configuration VALUES ('RMAEmail', '"Isaac Connor" <iconnor@connortechnology.com>', 'text', 'Email address to send RMA requests to.', 'Email Notifications');
INSERT INTO configuration VALUES ('InventoryEmail', '"Isaac Connor" <iconnor@connortechnology.com>', 'text', 'Email address to send Inventory notifications to.', 'Email Notifications');
INSERT INTO configuration VALUES ('UseCaptchaOnRegistration', 'Y', 'yes/no', 'Use a CAPTCHA on the registration to protect against automated bots.', 'Captcha Settings');
INSERT INTO configuration VALUES ('AcceptCreditApplications', 'N', 'yes/no', 'Whether to show links to a credit application page.', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('UserProfileRequiredFields', 'firstname', 'list', 'Command separated list of fields that are required to be filled in on the User Profile page.', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('RegistrationRequiredFields', 'firstname,password,verifypassword,email,agree_terms,date_of_birth', 'text', 'Fields which are required on the registration page.', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('VideoUploadDisclaimer', '', 'textarea', '', 'Disclaimers');
INSERT INTO configuration VALUES ('HelpdeskEmail', '"Helpdesk" <helpdesk@pleasurablethings.ca>', 'text', 'Email address to send helpdesk requests to.', 'Email Notifications');
INSERT INTO configuration VALUES ('TechSupportEmail', '"Support" <support@pleasurablethings.ca>', 'text', 'Email address to send technical support requests to.', 'Email Notifications');
INSERT INTO configuration VALUES ('UserRegistrationEmail', '"New Accounts" <newaccounts@pleasurablethings.ca>', 'text', 'Email address to send new user registrations to.', 'Email Notifications');
INSERT INTO configuration VALUES ('DateFormat', '%b %e, %Y', 'text', 'Format string used to show dates, without time', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('DateTimeFormat', '%Y-%m-%d %H:%M', 'text', 'Format string used when displaying timstamps with both a date and a time part. Edit', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('RegistrationDisclaimer', '', 'textarea', 'Text to show at bottom of registration', 'Disclaimers');
INSERT INTO configuration VALUES ('DefaultPricelist', '1', 'pricelist', 'Default Pricelist.', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('Timezone', 'America/Toronto', 'text', 'Timezone', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('UserProfileDisclaimer', '', 'textarea', '', 'Disclaimers');
INSERT INTO configuration VALUES ('RegistrationTopDisclaimer', '', 'textarea', 'Text shown at top of registration', 'Disclaimers');
INSERT INTO configuration VALUES ('AssetPath', '', 'text', 'Path to where assets are stored.', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('owner_id', '1', 'Supplier', 'Site Owner', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('WhyRegister', '', 'textarea', 'Text to display on login page (and maybe elsewhere) explaining why a person should register on the site.', 'Disclaimers');
INSERT INTO configuration VALUES ('meta-description', NULL, 'text', 'Default content to use for description meta tag.', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('meta-keywords', NULL, 'text', 'Default content for the keywords meta tag.', 'Miscellaneous Settings');
INSERT INTO configuration VALUES ('Small_Asset_Height', NULL, 'text', '', 'Asset Settings');
INSERT INTO configuration VALUES ('Medium_Asset_Height', NULL, 'text', '', 'Asset Settings');
INSERT INTO configuration VALUES ('Large_Asset_Height', NULL, 'text', '', 'Asset Settings');
INSERT INTO configuration VALUES ('Large_Asset_Width', '800', 'text', '', 'Asset Settings');
INSERT INTO configuration VALUES ('Medium_Asset_Width', '300', 'text', '', 'Asset Settings');
INSERT INTO configuration VALUES ('Small_Asset_Width', '50', 'text', '', 'Asset Settings');
INSERT INTO configuration VALUES ('PhotoUploadDisclaimer', '', 'textarea', 'Content to show on photo upload pages.', 'Disclaimers');

INSERT INTO configuration VALUES ('bitcoin_server', 'localhost', 'text', 'Bitcoin Server Hostname', 'Bitcoin Settings');
INSERT INTO configuration VALUES ('bitcoin_port', '8332', 'text', 'Bitcoin Server Port', 'Bitcoin Settings');
INSERT INTO configuration VALUES ('bitcoin_user', '', 'text', 'Bitcoin Server Username', 'Bitcoin Settings');
INSERT INTO configuration VALUES ('bitcoin_password', '', 'text', 'Bitcoin Server Password', 'Bitcoin Settings');
INSERT INTO configuration VALUES ('bitcoin_account', '', 'text', 'Bitcoin Account', 'Bitcoin Settings');
insert into Configuration values ('encrypt_passwords', '', 'text', 'Whether to use encrypted passwords.', 'System Settings');
