#!/usr/bin/perl -w
@INC=( '/etc/apache2/lib/perl', @INC );

use strict;
use Authen::Passphrase::BlowfishCrypt;

require sql;
require configuration;
require logger;
require misc;
require openprint;
require openprint::Object;
require openprint::User;

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

$log = new logger( 'debug' );
my ( $database, $host, $login, $password, $filename ) = @ARGV;
$login = $database if ! $login;
$password = $login if ! $password;

my %sql_server;
$sql_server{'database'} = $database;
$sql_server{'driver'}   = 'Pg';
$sql_server{'host'}   = $host if $host ne 'none';
$sql_server{'login'}    = $login;
$sql_server{'password'} = $password;

$dbh = sql::open_sql( $log, %sql_server );
if ( $dbh ) {
$log->debug("Opened SQL") if $dbh;
} else {
$log->debug("Not Opened SQL") if $dbh;
} # end if
$openprint::Object::no_cache = 1;
configuration::init( { db_name => $database, db_host=>$host, db_user=>$login } );

if ( $config{encrypt_passwords} ) {
	$dbh->disconnect();
	die "Passwords already crypted";
}

foreach my $User ( openprint::User->find(deleted=>[0,1,undef]) ) {
	if ( ! $User->password() ) {
		$log->warn( $User->name() . ' has no password.' );
		next;
	} # end if
	my $ppr = Authen::Passphrase::BlowfishCrypt->new(
                cost => 8, 
				salt_random=>1,
				#salt => sprintf('%-.16s', $User->email() ),
                passphrase =>$User->password() );
	$User->save({password=>$ppr->as_rfc2307});
	
} # end foreach User

if ( ! exists $config{encrypt_passwords} ) {
	sql::insert( undef, undef, 'Configuration', 'name','encrypt_passwords', 'value', 'Y', 'type','yes/no', 'category','System Settings','description','Whether to store passwords encrypted.' );
} else {
	sql::update( undef, undef, 'Configuration', [ 'name=?', 'encrypt_passwords' ], 'value','Y' );
}


$dbh->disconnect();
1;
__END__
