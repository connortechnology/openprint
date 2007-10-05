#!/usr/bin/perl

@INC=( '/etc/apache/lib/perl', @INC );

use strict;

require sql;
require configuration;
require crypto;
require logger;
require misc;

my $log = new logger( 'debug' );
my ( $database, $host, $login, $password, $filename ) = @ARGV;

my %sql_server;
$sql_server{'database'} = $database;
$sql_server{'driver'}   = 'Pg';
$sql_server{'host'}   = $host if $host ne 'none';
$sql_server{'login'}    = $login;
$sql_server{'password'} = $password;

my $dbh = sql::open_sql( $log, %sql_server );
if ( $dbh ) {
$log->debug("Opened SQL") if $dbh;
} else {
$log->debug("Not Opened SQL") if $dbh;
} # end if

if ( ! open( HANDLE, $filename ) ) {
	print( "Unable to open file: $filename, Reason: $!\n" );
	$dbh->disconnect();
	die;
} # end ife

my $crypt = crypto::get_crypt( $log, $dbh );

# read in the file
while (<HANDLE>) {
	$_ =~ /(.*),(.*)/;
	my $email = $1;
	my $password = $2;
	sql::update( $log, $dbh, 'tbl_Customer_Users', "strEmail='$email'", 'strPassword', misc::escape( $crypt->encrypt($password) ) );

} # end while
close(HANDLE);

$dbh->disconnect();
