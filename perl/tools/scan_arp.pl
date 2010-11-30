#!/usr/bin/perl -w
use strict;
use warnings;
use lib '/var/www/testing/perl';

use Getopt::Long;
use File::Basename qw(basename);
use openprint;

require logger;
require sql;
require openprint::Host;

use vars qw( $log $dbh %config);
*dbh = \$openprint::dbh;
*config = \%openprint::config;

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help', 
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','debug=s',
 );

*log = \$openprint::log;
$log = logger->new();
if ( $opts->{'debug'} ) {
	$log->level( $opts->{'debug'} );
} else {
	$log->level( 'warn' );
} # end if
if ($opts->{help}) {
    usage();
    exit 0;
}
if ( $$opts{'db_name'} ) {
	$dbh = sql::open_sql( $log,
		'host'      => $opts->{'db_host'},
		'database'  => $opts->{'db_name'},
		'driver'    => 'Pg',
		'login'     => $opts->{'db_user'},
		'password'  => $opts->{'db_pass'},
	);
	die 'Error opening db' if ! $dbh;
} else {
	$log->warn("Must specify database name in order to automatically load entries into db.\n");
} # end if

open(ARP, "arp -n|");
while ( my $line = <ARP> ) {
	next if $line =~ /^Address/;
	my ( $ip, $type, $mac, $flags, $iface ) = $line =~ /^([\.\d]{7,15})\s+(\w+)\s+([a-fA-F0-9\-\:]{17})\s+(\w+)\s+(\w+)$/;
	$log->debug( "line $ip $type $mac $flags $iface" ); 
	next if ! $dbh;
	if ( ! ( my $Host = openprint::Host->find_one('mac_any'=>$mac) ) ) {
		$log->info( "Host for $ip $mac not found, adding" );
		my $Host = new openprint::Host();	
		$Host->save({
			'mac'	=> [ $mac ], 
			'ip'	=>	$ip,
			'hostname'	=>	undef,
			} );
	} # end if
} # end while
close(ARP);

1;
__END__
