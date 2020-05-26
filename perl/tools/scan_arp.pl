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
if ( $opts->{debug} ) {
	$log->level( $opts->{debug} );
} else {
	$log->level('warn');
} # end if
if ($opts->{help}) {
    exit 0;
}
if ( $$opts{db_name} ) {
	$dbh = sql::open_sql( $log,
		'host'      => $opts->{'db_host'},
		'database'  => $opts->{'db_name'},
		'driver'    => 'Pg',
		'login'     => $opts->{'db_user'},
		'password'  => $opts->{'db_pass'},
	);
	die 'Error opening db' if ! $dbh;
} else {
	$log->warn('Must specify database name in order to automatically load entries into db.');
} # end if

open(ARP, 'arp -n|');
while ( my $line = <ARP> ) {
	next if $line =~ /^Address/;
	my ( $ip, $type, $mac, $flags, $iface ) = misc::trim( $line =~ /^([\.\d]{7,15})\s+(\w+)\s+([a-fA-F0-9\-\:]{17})\s+(\w+)\s+(\w+)$/ );
	if ( ! ($ip or $mac) ) {
		$log->debug("line $ip $type $mac $flags $iface");
		next;
	}
	
	next if ! $dbh;
	
	my @HIs = openprint::Host_Interface->find(mac=>$mac);
	$log->debug('Have ' . @HIs . ' interfaces matching '.$mac);
	if ( @HIs ) {
		foreach my $HI ( @HIs ) {
			if ( !$HI->ip() ) {
				$log->debug("Updating HI's ip to $ip");
				$HI->save({ip=>$ip});
			} else {
				$log->debug("not Updating HI's ip to $ip from $$HI{ip}");
			} # end if
		} # end foreach HI
	} else {
		@HIs = openprint::Host_Interface->find(ip=>$ip);
		$log->debug('Have ' . @HIs . ' interfaces matching '.$ip);
		if ( @HIs ) {
			if ( $mac ) {
				foreach my $HI ( @HIs ) {
					if ( ! $HI->mac() ) {
						$HI->save({mac=>$mac});
					} # end if
				} # end foreach HI
			} # end if mac
		} else {
			$log->info( "Host for $ip $mac not found, adding" );
			my $Host = new openprint::Host();	
			$Host->save({
					hostname	=>	'unknown',
					description => 	'Discovered by scan_arp.',
					} ) if ( $mac or $ip );
			my $HI = new openprint::Host_Interface();
			$HI->save({host_id=>$Host->id(), 
					'mac'	=> $mac, 
					'ip'	=> $ip,
					});
		} # end if
	} # end if

	#if ( $Host and ! $Host->hostname() ) {
		#if ( $_ = $Host->resolve() ) {
			#$Host->save({'hostname'=>$_});
		#} # end if
	#} # end if
	sleep 1;
} # end foreach line of arp
close(ARP);

1;
__END__
