#!/usr/bin/perl
use utf8;
use lib '/var/www/testing/perl';
use strict;
use LWP;

require configuration;
require sql;
require sets;
require logger;
require openprint::Host;
require openprint::Email;
require openprint::Log;
require Net::Ping;

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
$log = logger->new({level=>'debug'});

use Getopt::Long;
use File::Basename qw(basename);

my $opts = {};
GetOptions($opts, 'help', 
		'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s', 'debug=s', 'command=s', 'position=s','type=s','hostname=s',
		);

if ($opts->{help}) {
    usage();
    exit 0;
}

my $program = basename($0);
# Get our configuration information
$_ = configuration::from_file('/etc/openprint/camera_command.conf');
$log->error($_) if $_;
configuration::merge($opts);

foreach my $param ( 'db_name','db_user','db_pass', 'command' ) {
	if ( ! $config{$param} ) {
		die "$program: missing required --$param parameter";
	} # end if
} # end foreach required-param

$log->file( $config{log_file} ) if $config{log_file};
$log->level( $config{log_level} ) if $config{log_level} ne 'debug';

if ( $config{pid_file} ) {
	my $pidh;
	if (open($pidh, '> '.$config{pid_file} ) ) {
		print $pidh $$."\n"; 
		close($pidh);
	} else {
		die 'Unable to open pid file';
	} # end if
} # end if

$log->debug("Connecting to db");	
$dbh = sql::open_sql( $log,
		host		=> $config{db_host},
		database	=> $config{db_name},
		driver		=> 'Pg',
		login		=> $config{db_user},
		password	=> $config{db_pass},
		);
if ( ! $dbh ) {
	die "Error opening db. $!";
} # end if
configuration::init( $opts );
$_ = configuration::from_file('/etc/openprint/camera_command.conf');
$log->error($_) if $_;
configuration::merge($opts);

# udp has less network traffic overhead
my $p = Net::Ping->new('icmp',10);

my @Hosts = openprint::Host->find(
	'monitored'=>1,
	( $$opts{type} ? ( type=>[ split(',',$$opts{type})] ) : ( 'type in'=>[ 'AIC500', 'AIC500W', 'AIC777W', 'AIC747W','AIC250','AIC250W' ] ) ),
	( $$opts{hostname} ? ( hostname=>$$opts{hostname} ) : () ),
	);
foreach my $Host ( @Hosts ) {
	if ( ! $Host->ip() ) {
		$log->debug( "Camera without ip: " . $Host->to_string() );
		next;
	} # end if
	my @ping = $p->ping($Host->ip());
	my $ping = $ping[0];
#$openprint::log->debug("Ping1: @ping");
	if ( ! @ping ) {
		$log->warn("Problem with ping for " . $Host->hostname() );
		next;
	} # end if

	if ( $Host->online() and $ping ) {

		if ( sets::isin( $Host->type(), [ 'AIC500', 'AIC500W', 'AIC777W', 'AIC747W' ] ) ) {
			my $browser = LWP::UserAgent->new();
			$browser->credentials( $Host->hostname().':80', 'SkyIPCam', 'admin'=>'p1GraPHic' );
			if ( $$opts{command} eq 'reboot' ) {
				$log->debug('Sending reboot to ' . $Host->hostname());
				my $response = $browser->get('http://'.$Host->hostname().'/admin/reboot.cgi?type=0');
				$log->debug($response->is_success);
			} elsif ( $$opts{command} eq 'move' ) {
				$log->debug('Sending move to ' . $Host->hostname() . " position $$opts{position}");
				my $response = $browser->get('http://'.$Host->hostname().'/admin/ptctl.cgi?move='.$$opts{position});
				$log->debug('Success?'.$response->is_success);
			} else {
				$log->error("Unknown command $$opts{command}");
			} # end if
		} elsif ( sets::isin( $Host->type(), [ 'AIC250', 'AIC250W' ] ) ) {
			if ( $$opts{command} eq 'reboot' ) {
				$log->debug('Sending reboot to ' . $Host->hostname());
				my $browser = LWP::UserAgent->new();
				$browser->credentials( $Host->hostname().':80', 'Netcam', 'admin'=>'p1GraPHi' );
				my $response = $browser->get('http://'.$Host->hostname().'/Reply.htm?Reset=Yes');
				$log->debug($response->is_success);
			} else {
				$log->error("Unknown command $$opts{command}");
			} # end if
		
		} elsif ( $Host->type() ) {
			$log->warn("unsupported type: " . $Host->type() );
		} # end if
	} elsif ( $Host->online() ) {
		$log->debug("No ping for $$Host{hostname}");
	} else {
		$log->debug("$$Host{hostname} is offline: ping $ping");
	} # end if online
} # end foreach $Host
$p->close();
$dbh->disconnect() if $dbh;
exit 0;

sub usage {
	print <<EOH;

usage: reboot_camera [--help] 

The purpose of this script is to monitor hosts for uptime

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

1;
__END__
