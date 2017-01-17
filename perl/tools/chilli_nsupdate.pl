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
require openprint::Host_Interface;

use vars qw( $log $dbh %config);
*dbh = \$openprint::dbh;
*config = \%openprint::config;

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help', 
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','log_level=s','config=s',
 );
if ($$opts{help}) {
    usage();
    exit 0;
}
my %defaults = (
    config  =>  "/etc/openprint/$program.conf",
);
foreach my $default ( keys %defaults ) {
    $$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach


*log = \$openprint::log;
$openprint::log = logger->new('debug');
configuration::init( );
$_ = configuration::from_file( $$opts{config} );
die $_ if $_;
configuration::merge( $opts );

foreach my $param ( 'db_name','db_user','db_pass' ) {
	if ( ! $openprint::config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param

$config{log_level} = 'debug' if ! $config{'log_level'};
$log = logger->new( {'file'=>$config{'log_file'}, 'level'=>$config{'log_level'}} );


if ( $config{'log_level'} eq 'debug' ) {
	foreach my $k ( keys %ENV ) {
		$log->debug("Environment: $k => $ENV{$k}");
	}
}

if ( ! $ENV{'CALLING_STATION_ID'} ) {
	$log->error("No CALLING_STATION_ID");
	exit(1);
} elsif ( ! $ENV{'FRAMED_IP_ADDRESS'} ) {
	$log->error("No FRAMED_IP_ADDRESS");
	exit(1);
} # end if

if ( $config{'db_name'} ) {
	$openprint::dbh = sql::open_sql( $log,
			'host'      => $config{'db_host'},
			'database'  => $config{'db_name'},
			'driver'    => 'Pg',
			'login'     => $config{'db_user'},
			'password'  => $config{'db_pass'},
			);
	die 'Error opening db' if ! $dbh;
} else {
	$log->error("Must specify database name in order to look up hosts.\n");
	exit(1);
} # end if
my @Interfaces = openprint::Host_Interface->find(mac=>$ENV{'CALLING_STATION_ID'});
if ( @Interfaces ) {
	foreach my $Interface ( @Interfaces ) {
		if ( $Interface->dhcp() ) {
			if ( $Interface->ip() ne $ENV{'FRAMED_IP_ADDRESS'} ) {
				$_ = $Interface->save({ip=>$ENV{'FRAMED_IP_ADDRESS'}});
				$log->error($_) if $_;

				my $Host = $Interface->Host();
				my $hostname = $Host->hostname();
				if ( $hostname ) {
					if ( $hostname !~ /.internal.point-one.com$/ ) {
						$log->debug("TRanforming $hostname into $hostname.internal.point-one.com");
						$hostname .= '.internal.point-one.com';
					}


					if ( open NSUPDATE, "| nsupdate" ) {
						$log->debug("Updating $hostname to $ENV{FRAMED_IP_ADDRESS}");
						print NSUPDATE "server 192.168.2.1\n";
						print NSUPDATE "update delete $hostname. IN A\n";
						print NSUPDATE "update add $hostname. 86400 IN A $ENV{FRAMED_IP_ADDRESS}\n";
						print NSUPDATE "send\n";
						close NSUPDATE;
					} else {
						$log->error("Unable to open NSUPDATE $!");
					} # end if 
				} # end if 
			} else {
				$log->debug("IP unchanged");
			} # end if
		} else {
			$log->debug("IP not changed because dhcp not set for mac $ENV{'CALLING_STATION_ID'} $ENV{'FRAMED_IP_ADDRESS'}");
		} # end if Host->dhcp
	} # end foreach Inteface
} else {
	$log->debug("Host not found for mac $ENV{'CALLING_STATION_ID'}");
	my $Host = new openprint::Host();
	$Host->save({hostname=>'unknown ' . $ENV{'CALLING_STATION_ID'}});
	my $HI = new openprint::Host_Interface();
	$HI->save({ mac=>$ENV{'CALLING_STATION_ID'}, address=>$ENV{'FRAMED_IP_ADDRESS'}, host_id=>$Host->id(), dhcp=>1 });
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
