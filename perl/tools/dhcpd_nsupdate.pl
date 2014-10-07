#!/usr/bin/perl
use strict;
use warnings;
use lib '/var/www/testing/perl';

use Getopt::Long qw(GetOptions);
use File::Basename qw(basename);
require openprint;
require logger;
require sql;
require configuration;
require openprint::Host;

use vars qw( $log $dbh %config);
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*log = \$openprint::log;
$log = logger->new('debug');

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help', 
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','log_level=s',
 );


my %defaults = (
    config  =>  "/etc/openprint/$program.conf",
);
foreach my $default ( keys %defaults ) {
    $$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach

configuration::init( );
configuration::from_file( $$opts{config} );
configuration::merge( $opts );

foreach my $param ( 'db_name','db_user','db_pass' ) {
	if ( ! $config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param

$config{'log_level'} = 'debug' if ! $config{'log_level'};
$log = logger->new( {'file'=>$config{'log_file'}, 'level'=>$config{'log_level'}} );

if ($config{help}) {
    usage();
    exit 0;
}

my ( $ip, $mac, $hostname ) = @ARGV;

if ( $mac ) {
	if ( $config{'db_name'} ) {
		$dbh = sql::open_sql( $log,
				host      => $config{'db_host'},
				database  => $config{'db_name'},
				driver    => 'Pg',
				login     => $config{'db_user'},
				password  => $config{'db_pass'},
				);
		die 'Error opening db' if ! $dbh;
	} else {
		$log->error("Must specify database name in order to look up hosts.\n");
		exit(1);
	} # end if
	my $Interface = openprint::Host_Interface->find_one(mac=>$mac);
	if ( $Interface ) {
		if ( $Interface->dhcp() ) {
			if ( $Interface->ip() ne $ip ) {
				$_ = $Interface->save({ip=>$ip});
				$log->error($_) if $_;

				my $Host = $Interface->Host();

				my $hostname = $Host->hostname();
				if ( $hostname !~ /.internal.point-one.com$/ ) {
					$log->debug("TRanforming $hostname into $hostname.internal.point-one.com");
					$hostname .= '.internal.point-one.com';
				}
			} else {
				$log->debug("IP unchanged");
			} # end if
		} else {
			$log->debug("IP not changed because dhcp not set for mac $mac $ip");
		} # end if Host->dhcp
	} else {
		my $Host = new openprint::Host();
		$Host->save({ hostname=>$hostname} );
		my $Interface = new openprint::Host_Interface();
		$Interface->save({ ip=>$ip, mac => $mac, host_id=>$$Host{id} });

		$log->debug("Host not found for mac $mac");

	} # end if Hosts
	$dbh->disconnect();
} else {
	$log->error("No CALLING_STATION_ID");
} # end if
exit(0);

sub usage {
	print <<EOH;

usage: chilli_nsupdate.pl [--help] 

The purpose of this script is to do a dns update when someone connects to the chilli hotspot

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

1;
__END__
