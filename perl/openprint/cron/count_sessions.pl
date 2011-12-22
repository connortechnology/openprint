#!/usr/bin/perl 
use lib '/var/www/testing/perl';
use strict;
use warnings;

require sql;
require logger;
use Apache::Session::Postgres;
use Getopt::Long;

use openprint ();
use vars qw($log $dbh %config);
*dbh = \$openprint::dbh;
*log = \$openprint::log;
*config = \%openprint::config;

my $program = 'count_sessions.pl';
$log = logger->new('debug');
my $opts = {};
GetOptions($opts, 'help', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','output=s','debug=s');

if ($opts->{help}) {
    usage();
    exit 0;
}
if ( $opts->{debug}) {
    $$log{level} = $opts->{debug};
}

unless ($opts->{db_name}) {
    print STDERR "$program: missing required --db_name parameter\n";
    exit 1;
}
$opts->{db_user} = $opts->{db_name} if ! $opts->{db_user};
$opts->{db_pass} = $opts->{db_name} if ! $opts->{db_pass};

$dbh = sql::open_sql( $log,
        'host'      => $opts->{db_host},
        'database'  => $opts->{db_name},
        'driver'    => 'Pg',
        'login'     => $opts->{db_user},
        'password'  => $opts->{db_pass},
        );

die 'Error opening db' if ! $dbh;

my $count = 0;
my @session_ids = sql::execute( $log, $dbh, q{SELECT id FROM sessions} );
foreach my $session ( @session_ids ) {
    $session =~ s/\s//g;
    my %session;
    if ( ! eval q`tie %session, 'Apache::Session::Postgres', $session, { Handle => $dbh, Commit => 0, IDLength => 8 }` ) {
        $log->debug("Error fetching Session: $session: $@");
        next;
    }
    if ( ! $session{'lastupdated'} ) {
		$log->warn("Updating time $session");
        $session{'lastupdated'} = time;
        untie %session;
    } elsif ( time - $session{'lastupdated'} < ( 60*60 ) ) {
		$count += 1;
	} # end if
	undef %session;
} # end foreach
@session_ids = ();

if ( $$opts{'output'} ) {
	open (MYFILE, '>'.$$opts{'output'}) or die "unable to open output at $$opts{output} : $!";
	print MYFILE "$count currently online\n";
	close (MYFILE); 
} # end if
$dbh->disconnect() if $dbh;

sub usage {
	print <<EOH;

usage: $program [--help] [--db_name \$db_name] [--db_host \$db_host] [--db_user \$db_user] [--db_pass \$db_pass] [ --output filename ]

The purpose of this script is to monitor the hotfolders configured for each
press for PPF files and perform conversions for Heidelberg JDF, Merge front 
and backs for presses that require it, and to import the PPF previews and 
other data into the IntelligentQuote system.

Command-line options:

	--help		Displays this message.

	--db_host	The hostname of the machine on which the database resides.

	--db_name	The name of the database.
	
	--db_user	The name of the user to use when connecting to the database.

	--db_pass	The password to use when connecting to the database.

    --output    File to store the session count in.

EOH
}
1;
__END__
