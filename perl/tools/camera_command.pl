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
		'log_level=s','log_file=s',
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
		port		=> $config{db_port},
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
	monitored=>1,
	( $$opts{type} ? ( type=>[ split(',',$$opts{type})] ) : ( type=>[ 'AIC500', 'AIC500W', 'AIC777W', 'AIC747W','AIC250','AIC250W', 'DLink DCS-910' ] ) ),
	( $$opts{hostname} ? ( hostname=>$$opts{hostname} ) : () ),
	);
if ( ! @Hosts ) {
	$log->error("NO hosts found for command.");
}
foreach my $Host ( @Hosts ) {
	my @ips = map { $_->ip() ? $_->ip() : () } $Host->Interfaces();
	if ( ! @ips ) {
		$log->debug( "Camera without ips: " . $Host->to_string() );
		next;
	} # end if
	my $ip = $ips[0];
	my @ping = $p->ping($ip);
	my $ping = $ping[0];
#$openprint::log->debug("Ping1: @ping");
	if ( ! @ping ) {
		$log->warn("Problem with ping for " . $Host->hostname() );
		next;
	} # end if

	if ( $Host->online() or $ping ) {
		if ( $$opts{command} eq 'reboot' ) {
			$log->debug('Sending reboot to ' . $Host->hostname());
			$Host->reboot();
		} elsif ( $$opts{command} eq 'move' ) {
			my $browser = LWP::UserAgent->new();
			$browser->credentials( $Host->hostname().':80', 'SkyIPCam', $Host->info('username'), $Host->info('password') );
			if ( sets::isin( $Host->type(), [ 'AIC777W', 'AIC747W' ] ) ) {
				$log->debug('Sending move to ' . $Host->hostname() . " position $$opts{position}");
				my $response = $browser->get('http://'.$Host->hostname().'/admin/ptctl.cgi?move='.$$opts{position});
				$log->debug('Success?'.$response->is_success);
			} else {
				$log->error("Host doesn't support moving");
			}
		} else {
			$log->error("Unknown command $$opts{command}");
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

usage: camera_command.pl [--help] 

The purpose of this script is to reboot or move cameras.

Command-line options:

		--db_name=s
		--db_host=s
		--db_user=s
		--db_pass=s
		--debug=s
		--command=s
		--position=s
		--type=s
		--hostname=s
		--log_level=s
		--log_file=s
		--help		Displays this message.

EOH
} # end sub usage

1;
__END__
