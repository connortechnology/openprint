#!/usr/bin/perl
use strict;
use warnings;
use lib '/var/www/testing/perl';

use Getopt::Long;
use File::Basename qw(basename);
use openprint;

require misc;
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
	my ( $ip, $type, $mac, $flags, $iface ) = misc::trim( $line =~ /^([\.\d]{7,15})\s+(\w+)\s+([a-fA-F0-9\-\:]{17})\s+(\w+)\s+(\w+)$/ );
	if ( ! ($ip or $mac) ) {
		$log->debug( "line $ip $type $mac $flags $iface" );
		next;
	}
	
	next if ! $dbh;
	my $Host = openprint::Host->find_one('mac any'=>$mac);
	if ( $Host ) {
		if ( ! $Host->ip() ) {
			$Host->save({'ip'=>$ip});
		} # end if
	} else {
		$Host = openprint::Host->find_one('ip'=>$ip);
		if ( $Host ) {
			$Host->save({'mac'=>[ $mac ] } ) if $mac;
		} else {
			$log->info( "Host for $ip $mac not found, adding" );
			$Host = new openprint::Host();	
			$Host->save({
					'mac'	=> [ $mac ], 
					'ip'	=>	$ip,
					'hostname'	=>	undef,
					'description' => 	'Discovered by scan_arp.',
					} ) if ( $mac or $ip );
		} # end if
	} # end if
	if ( $Host and ! $Host->hostname() ) {
		if ( $_ = $Host->resolve() ) {
			$Host->save({'hostname'=>$_});
		} # end if
	} # end if
} # end while
close(ARP);

1;
__END__
