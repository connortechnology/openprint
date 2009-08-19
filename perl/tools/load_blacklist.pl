#!/usr/bin/perl -w
use lib '/etc/apache2/lib/perl';

use sql;

use strict;
use Socket;
use Date::Parse;
use openprint;

require logger;

use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
$log = logger->new();
$log->{level} = "warn";

use Getopt::Long;
use File::Basename qw(basename);

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help', 
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','blacklist=s',
 );

if ($opts->{help}) {
    usage();
    exit 0;
}

unless ($opts->{db_name}) {
    print STDERR "$program: missing required --db_name parameter\n";
    exit 1;
}
unless ($opts->{db_user}) {
    print STDERR "$program: missing required --db_user parameter\n";
    exit 1;
}
unless ($opts->{db_pass}) {
    print STDERR "$program: missing required --db_pass parameter\n";
    exit 1;
}

$dbh = sql::open_sql( $log,
    'host'      => $opts->{'db_host'},
    'database'  => $opts->{'db_name'},
    'driver'    => 'Pg',
    'login'     => $opts->{'db_user'},
    'password'  => $opts->{'db_pass'},
);
die 'Error opening db' if ! $dbh;

die 'Must specify blacklist file' if ! $opts->{'blacklist'};

if ( open( FH, '<'.$opts->{'blacklist'} ) ) {
	foreach my $line (<FH>) {
		my $ip;
		if ( $line =~ /^(\d+\.\d+\.\d+\.\d+)$/ ) {
			# Is an IP
			$ip = $1;
			if ( ! $openprint::dbh->selectrow_hashref( 'SELECT * FROM blacklist WHERE ip=?', {}, $ip ) ) {
				print "Adding entry for $ip\n";
				if ( my $e = sql::insert( undef, undef, 'blacklist',['ip',$ip, 'updated_on', 'NOW()', 'count', 1] ) ) {
					print $e . "\n";
				} # end if
			} else {
				print "Not adding entry for $ip\n";
			} # end if
		} # end if
	} # end if
	close( FH );
} # end if

sub usage {
	print <<EOH;

usage: blacklist [--help] 

The purpose of this script is to monitor the AuthLog looking for attacks.

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

1;
__END__
