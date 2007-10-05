#!/usr/bin/perl
@INC = ( @INC, '/etc/apache/lib/perl' );
use strict;
use Mail::Sendmail;

require sql;
require misc;
require logger;
require configuration;

my $r;
my $log = logger->new('warn');
my %sql_server;

$sql_server{'database'} = 'point-one';
$sql_server{'host'} = 'www2';
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'point-one';
$sql_server{'password'} = 'point-1';
my $dbh = sql::open_sql( $log, %sql_server);

my $username = shift @ARGV;

#my $email_template = misc::load_file( $log, $ENV{'DOCUMENT_ROOT'} . '/email_content/email_template.html' );
#$info{'ReplacementText'} = "<!--#include virtual=\"/email_content/proofs_complete.html\"-->";
#$_ = encode_qp( ssi::variable_substitution( $r, $log, $dbh, $email_template, \%info ) );
#my @body = ('', $_, 'text/html', 'quoted-printable');
my $time = misc::pretty_date( localtime );
my %mail = (
		SMTP    => configuration::get_value( $log, $dbh, 'Mail Server'),
		FROM    => configuration::get_value( $log, $dbh, 'LoginEmail'),
		TO      => configuration::get_value( $log, $dbh, 'LoginEmail'),
		SUBJECT => "System Login Notification",
		BODY	=> "
At $time, $username logged in to www.point-one.com at a system level."
		);
sendmail(%mail) || $log->debug( "Error: $Mail::Sendmail::error\n" );
#misc::send_email_with_attachment( $log, \%mail );


$dbh->disconnect();
