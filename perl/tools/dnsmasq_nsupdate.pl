#!/usr/bin/perl -wU
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
$_ = configuration::from_file( $$opts{config} );
die $_ if $_;
configuration::merge( $opts );

foreach my $param ( 'db_name','db_user','db_pass' ) {
	if ( ! $config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param

$openprint::config{log_level} = 'debug' if ! $config{log_level};
$openprint::log = logger->new( { file=>$config{log_file}, level=>$config{log_level}} );

if ($config{help}) {
    usage();
    exit 0;
}

my ( $op, $mac, $ip, $hostname ) = @ARGV;
if ( ! $mac ) {
	usage();
	die "You must specify a mac.";
} elsif ( ! $ip ) {
	usage();
	die "You must specify a ip.";
}

if ( $config{db_name} ) {
	$openprint::dbh = sql::open_sql( $log,
			host      => $config{db_host},
			port		=>	$config{db_port},
			database  => $config{db_name},
			driver    => 'Pg',
			login     => $config{db_user},
			password  => $config{db_pass},
			);
	die 'Error opening db' if ! $dbh;
} else {
	$log->error("Must specify database name in order to look up hosts.\n");
	exit(1);
} # end if
my @Interfaces = openprint::Host_Interface->find(mac=>$mac);
if ( @Interfaces ) {
	foreach my $Interface ( @Interfaces ) {
		if ( $Interface->dhcp() ) {
			if ( $Interface->ip() ne $ip ) {
				$_ = $Interface->save({ip=>$ip});
				$log->error($_) if $_;
				(new openprint::Log())->save( { object_id => $Interface->host_id(), object_type=>'openprint::Host', note=>'IP Address removed because it is taken by host ' . $Interface->Host()->link_to(), action=>'IP Changed' } );

				my $Host = $Interface->Host();

				my $hostname = $Host->hostname();
			} else {
				$log->debug("IP unchanged for $mac => $ip => $hostname");
			} # end if
		} else {
			$log->debug("IP not changed because dhcp not set for mac $mac $ip $hostname");
		} # end if Host->dhcp

		foreach my $I ( openprint::Host_Interface->find( 'mac !=' => $mac, ip=>$ip ) ) {
			$I->save({ip=>undef});
			(new openprint::Log())->save( { Object => $I->Host, note=>'IP Address removed because it is taken by host ' . $Interface->Host()->link_to(), action=>'IP Changed' } );
		} # end foreach I
	} # end foreach Interface
} else {
	my $Host = new openprint::Host();
	$Host->save({ hostname=>$hostname} );
	my $Interface = new openprint::Host_Interface();
	$Interface->save({ ip=>$ip, mac => $mac, host_id=>$$Host{id}, dhcp=>1 });

	$log->debug("Host not found for mac $mac $hostname");

} # end if Hosts

$dbh->disconnect() if $dbh;
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
