#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;
use Math::Prime::Util qw( next_prime );
require sql;
require logger;

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

$log = logger->new();
$log->{level} = "warn";

use File::Basename qw(basename);
use Getopt::Long ();

my $program = basename($0);

my $opts = {};
Getopt::Long::GetOptions($opts, 'help', 'config=s',
	'log_file=s', 'log_level=s',
	'pid_file=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
	'port=s','debug=s',
);

if ($opts->{help}) {
	usage();
	exit 0;
} # end if

$dbh = sql::open_sql( $log,
    'host'      => $opts->{'db_host'},
    'database'  => $opts->{'db_name'},
    'driver'    => 'Pg',
    'login'     => $opts->{'db_user'},
    'password'  => $opts->{'db_pass'},
) if $opts->{'db_name'};
die 'Error opening db' if ! $dbh;
 
print "Find primes from: ";
chomp(my $o = <>);
if ( ! $o ) {
	( $o ) = sql::execute( $log,  $dbh ,'SELECT prime FROM primes ORDER BY digit_length DESC,prime DESC LIMIT 1' );
	if ( ! $o ) {
		die 'Must speifiy 1';
	}
}
print "to: ";
chomp(my $e = <>);
 
 
my $p = next_prime($o);
while ( ( !$e) or ( $p <= $e ) ) {
	my $length = length $p;
	print "$p is prime, length $length\n";
	sql::insert( $log, $dbh, 'primes', { prime=>$p, digit_length=> $length } );
	if ( $dbh->errstr() ) {
		die $dbh->errstr();
	}
	$p = next_prime($p + 1);
}

sub usage() {
}

1;
__END__
