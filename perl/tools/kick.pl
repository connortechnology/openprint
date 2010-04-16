#!/usr/bin/perl 
use lib '/var/www/p1/perl';
use strict;
use warnings;

require sql;
require ssi;
require logger;
require misc;
require configuration;
require openprint::Object;
require openprint::User;
use Apache::Session::Postgres;

use openprint ();
use vars qw($log $dbh %config);
*dbh = \$openprint::dbh;
*log = \$openprint::log;
*config = \$openprint::config;

my $r;
$log = logger->new('warn');

$dbh = sql::open_sql( $log, 
	'host'		=> $ARGV[0],
	'database'	=> $ARGV[1],
	'driver'	=> 'Pg',
	'login'		=> $ARGV[2],
	'password'	=> $ARGV[3],
);
die 'Error opening db' if ! $dbh;
$openprint::Object::no_cache = 1;

if ( ! $ARGV[4] ) {
	die "Must have an email address to log ogg";
}

my $User = openprint::User::find_one( 'email'=>lc $ARGV[4] );
if ( ( ! $User ) or ( ! $User->id() ) ) {
	die "No user found for $ARGV[4]";
} # end if

# Clear out old sessions
my @session_ids = sql::execute( $log, $dbh, q{SELECT id FROM sessions} );
$log->warn("Loaded: " . @session_ids . " sessions");
my $deleted_session_count = 0;
foreach my $session ( @session_ids ) {
    $session =~ s/\s//g;
    my %session;
    if ( ! eval q`tie %session, 'Apache::Session::Postgres', $session, { Handle => $dbh, Commit => 0, IDLength => 8 }` ) {
        $log->debug("Error fetching Session: $session: $@");
        next;
    }
    if ( $session{'user_id'} and $session{'user_id'} == $User->id() ) {
        untie %session;
		sql::execute( 0, $dbh, q{DELETE FROM sessions where id=?}, $session );
		$deleted_session_count += 1;
	} else {
		untie %session;
	} # end if
} # end foreach
$log->warn("Deleted $deleted_session_count sessions");

1;
__END__
