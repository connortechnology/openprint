#!/usr/bin/perl -w
use utf8;
use lib '/var/www/point-one/perl';
use strict;
use LWP;

require configuration;
require sql;
require openprint::Host;
require logger;
require openprint::Email;
require openprint::Log;

use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
$log = logger->new();
$log->{level} = 'debug';

use Getopt::Long;
use File::Basename qw(basename);

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help', 
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','blacklist=s', 'debug=s', 'host_id=s',
 );

if ($opts->{help}) {
    usage();
    exit 0;
}

my %defaults = (
	config	=>	'/etc/openprint/camera_reboot.conf',
	ping_type	=>	'icmp',
);
foreach my $default ( keys %defaults ) {
	$$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach
$log->debug("Init config");
configuration::init( );
configuration::from_file( $$opts{config} );
configuration::merge( $opts );

foreach my $param ( 'db_name','db_user','db_pass' ) {
	if ( ! $config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param

if ( $config{'site_url'} ) {
	$config{'siteURL'} = $config{'site_url'};
	$config{'ExternalSiteURL'} = $config{'site_url'};
} # end if
$config{'SiteTitle'} = $config{'site_title'};
$config{'SkinPath'} = $config{'skin_path'};

$config{'log_level'} = 'debug' if ! $config{'log_level'};
$log = logger->new( {'file'=>$config{'log_file'}, 'level'=>$config{'log_level'}} );

$log->debug("Connecting to db");	
$dbh = sql::open_sql( $log,
		'host'		=> $config{'db_host'},
		'database'	=> $config{'db_name'},
		'driver'	=> 'Pg',
		'login'		=> $config{'db_user'},
		'password'	=> $config{'db_pass'},
		);
if ( ! $dbh ) {
	die "Error opening db. $!";
} # end if
$log->debug("Connected to db");

require Net::Ping;
# udp has less network traffic overhead
my $p = Net::Ping->new('icmp',10);

my @Hosts = $$opts{host_id} ? openprint::Host->find(id=>$$opts{host_id}) : openprint::Host->find('monitored'=>1,'type in'=>[ 'AIC500', 'AIC500W', 'AIC777W', 'AIC747W','AIC250','AIC250W' ]);
$log->debug( 'Monitoring ' . @Hosts . ' hosts.' );
foreach my $Host ( @Hosts ) {
	foreach my $HI ( $Host->Interfaces() ) {
		if ( ! $HI->ip() ) {
			$log->debug( "Monitored host without ip: " . $Host->to_string() );
			next;
		} # end if
		my @ping = $p->ping($HI->ip());
		my $ping = $ping[0];
	#$openprint::log->debug("Ping1: @ping");
		if ( ! @ping ) {
			$log->warn("Problem with ping for " . $Host->hostname() );
			next;
		} # end if

		if ( $Host->online() and $ping ) {
			$Host->reboot();
		} elsif ( $Host->online() ) {
			$log->debug("No ping for $$Host{hostname}");
		} else {
			$log->debug("$$Host{hostname} is offline: ping $ping");
		} # end if online
	} # end foreach HI
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
