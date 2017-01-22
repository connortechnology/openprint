<?php
// 
// Postfix Admin 
// by Mischa Peters <mischa at high5 dot net>
// Copyright (c) 2002 - 2005 High5!
// License Info: http://www.postfixadmin.com/?file=LICENSE.TXT
//
// File: config.inc.php
//
if (preg_match ("/config\.inc\.php/", $_SERVER['PHP_SELF']))
{
   header ("Location: login.php");
   exit;
}

// Postfix Admin Path
// Set the location to your Postfix Admin installation here.
$CONF['postfix_admin_url'] = '';
$CONF['postfix_admin_path'] = '';

// Language config
// Language files are located in './languages'.
$CONF['default_language'] = 'en';

// Database Config
// mysql = MySQL 3.23 and 4.0
// mysqli = MySQL 4.1
// pgsql = PostgreSQL
$CONF['database_type'] = 'pgsql';
$CONF['database_host'] = 'database';
$CONF['database_user'] = 'postfix';
$CONF['database_password'] = 'postfix';
$CONF['database_name'] = 'mail';
$CONF['database_prefix'] = '';

// Site Admin
// Define the Site Admins email address below.
// This will be used to send emails from to create mailboxes.
$CONF['admin_email'] = 'postmaster@point-one.com';

// Mail Server
// Hostname (FQDN) of your mail server.
// This is used to send email to Postfix in order to create mailboxes.
$CONF['smtp_server'] = 'localhost';
$CONF['smtp_port'] = '25';

// Encrypt
// In what way do you want the passwords to be crypted?
// md5crypt = internal postfix admin md5
// system = whatever you have set as your PHP system default
// cleartext = clear text passwords (ouch!)
$CONF['encrypt'] = 'cleartext';

// Generate Password
// Generate a random password for a mailbox and display it.
// If you want to automagically generate paswords set this to 'YES'.
$CONF['generate_password'] = 'NO';

// Page Size
// Set the number of entries that you would like to see
// in one page.
$CONF['page_size'] = '10';

// Default Aliases
// The default aliases that need to be created for all domains.
$CONF['default_aliases'] = array (
);

// Mailboxes
// If you want to store the mailboxes per domain set this to 'YES'.
// Example: /usr/local/virtual/domain.tld/username@domain.tld
$CONF['domain_path'] = 'YES';
// If you don't want to have the domain in your mailbox set this to 'NO'.
// Example: /usr/local/virtual/domain.tld/username
$CONF['domain_in_mailbox'] = 'NO';

// Default Domain Values
// Specify your default values below. Quota in MB.
$CONF['aliases'] = '0';
$CONF['mailboxes'] = '0';
$CONF['maxquota'] = '0';

// Quota
// When you want to enforce quota for your mailbox users set this to 'YES'.
$CONF['quota'] = 'NO';
// You can either use '1024000' or '1048576'
$CONF['quota_multiplier'] = '1024000';

// Transport
// If you want to define additional transport options for a domain set this to 'YES'.
// Read the transport file of the Postfix documentation.
$CONF['transport'] = 'NO';

// Virtual Vacation
// If you want to use virtual vacation for you mailbox users set this to 'YES'.
// NOTE: Make sure that you install the vacation module. http://high5.net/postfixadmin/
$CONF['vacation'] = 'YES';
// This is the autoreply domain that you will need to set in your Postfix
// transport maps to handle virtual vacations. It does not need to be a
// real domain (i.e. you don't need to setup DNS for it).
$CONF['vacation_domain'] = 'autoreply.point-one.com';

// Alias Control
// Postfix Admin inserts an alias in the alias table for every mailbox it creates.
// The reason for this is that when you want catch-all and normal mailboxes
// to work you need to have the mailbox replicated in the alias table.
// If you want to take control of these aliases as well set this to 'YES'.
$CONF['alias_control'] = 'YES';

// Special Alias Control
// Set to 'NO' if you don't want your domain admins to change the default aliases.
$CONF['special_alias_control'] = 'YES';

// Logging
// If you don't want logging set this to 'NO';
$CONF['logging'] = 'YES';

// Header
$CONF['show_header_text'] = 'NO';
$CONF['header_text'] = ':: Postfix Admin ::';

// Footer
// Below information will be on all pages.
// If you don't want the footer information to appear set this to 'NO'.
$CONF['show_footer_text'] = 'YES';
$CONF['footer_text'] = 'Return to point-one.com';
$CONF['footer_link'] = 'http://www.point-one.com';

// Welcome Message
// This message is send to every newly created mailbox.
// Change the text between EOM.
$CONF['welcome_text'] = <<<EOM
Hi,

Welcome to your new account.
EOM;

//
// END OF CONFIG FILE
//
?>
