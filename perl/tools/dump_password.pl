#!/usr/bin/perl
@INC = ( '/etc/apache/lib/perl', @INC );
use strict;

require sql;
require configuration;
require logger;
require misc;
require crypto;

my $log = new logger( 'warn' );

my ( $database, $host, $login, $password ) = @ARGV;


my %sql_server;
$sql_server{'database'} = $database;
$sql_server{'driver'}   = 'Pg';
$sql_server{'host'}   = $host;
$sql_server{'login'}    = $login;
$sql_server{'password'} = $password;

my $dbh = sql::open_sql( $log, %sql_server );

my $crypt = crypto::get_crypt( $log, $dbh );
$_ = "SELECT strEmail, strPassword FROM tbl_Customer_Users";
my @data = sql::sql_statement( $log, $dbh, $_ );

while ( @data ) {
	my $email = shift @data;
	my $password = shift @data;
	print "$email," . $crypt->decrypt( misc::unescape($password) ) . "\n";
} # end while

$dbh->disconnect();
