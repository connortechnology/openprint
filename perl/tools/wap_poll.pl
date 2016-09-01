#!/usr/bin/perl -w
use utf8;
use lib '/var/www/testing/perl';
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
$log = logger->new( 'debug' );

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
	config	=>	'/etc/openprint/wap_poll.conf',
);
foreach my $default ( keys %defaults ) {
	$$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach
$log->debug("Init config");
configuration::init( );
configuration::from_file( $$opts{config} );
configuration::merge( $opts );

foreach my $param ( 'db_name','db_user','db_pass' ) {
	if ( ! $openprint::config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param

require LWP;
my $browser = LWP::UserAgent->new();

if ( $config{'site_url'} ) {
	$config{'siteURL'} = $config{'site_url'};
	$config{'ExternalSiteURL'} = $config{'site_url'};
} # end if
$config{'SiteTitle'} = $config{'site_title'};
$config{'SkinPath'} = $config{'skin_path'};

$config{'log_level'} = 'debug' if ! $config{'log_level'};
$log = logger->new( {'file'=>$config{'log_file'}, 'level'=>$config{'log_level'}} );

$log->debug("Connecting to db");	
$openprint::dbh = sql::open_sql( $log,
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

use HTML::TreeBuilder;
require Net::Ping;
# udp has less network traffic overhead
my $p = Net::Ping->new('icmp',10);

my @Hosts = $$opts{host_id} ? openprint::Host->find(id=>$$opts{host_id}) : openprint::Host->find('type in'=>[ 'WG602v3' ]);
$log->debug( 'WAP polling ' . @Hosts . ' hosts.' );
foreach my $Host ( @Hosts ) {
	foreach my $HI ( $Host->Interfaces() ) {
		if ( ! $HI->ip() ) {
			$log->warn( "Polled host without ip: HOST: " . $Host->to_string() );
			$log->warn( "Polled host without ip: Interface: " . $HI->to_string() );
			next;
		} # end if
    $log->debug("Pinging $$Host{hostname} at $$HI{ip}");
		my @ping = $p->ping($HI->ip());
		my $ping = $ping[0];
	#$openprint::log->debug("Ping1: @ping");
		if ( ! @ping ) {
			$log->warn("Problem with ping for " . $Host->hostname() );
			next;
		} # end if

		if ( $Host->online() and $ping ) {
      my $initial_url;
      my $url;
      my $args;
      my $method = 'get';

      if ( $Host->type() eq 'WG602v3' ) {
        $url = 'http://'.$$HI{ip}.'/cgi-bin/stalist.html';

        my $response = $browser->get($initial_url ? $initial_url : $url);
        if ( ! $response->is_success ) {

          my $headers = $response->headers();
          my ( $auth, $tokens ) = $$headers{'www-authenticate'} =~ /^(\w+)\s+(.*)$/;
          my %tokens = map { /(\w+)="([^"]+)"/i } split(', ', $tokens );
          if ( $tokens{realm} ) {
            $openprint::log->debug("tokens: $tokens realm: $tokens{realm}");
            $browser->credentials( $HI->ip().':80', $tokens{realm}, $Host->info('username'), $Host->info('password') );
            $response = $browser->$method($url, $args ? $args : () );
          } else {
            $log->error("No realm");
          } # end if
        } # end if

        if ( ! $response->is_success ) {
          $log->error("Should have worked.");
          $openprint::log->error( $response->status_line );
          $openprint::log->error( $response->content );
          my $headers = $response->headers();
          foreach my $k ( keys %$headers ) {
            $openprint::log->debug("Initial Header $k => $$headers{$k}");
          }  # end foreach
        } else {
          my ($assoc_list_line ) = $response->content() =~ /var assoc_list='([^']*)';/m;
			if ( $assoc_list_line ) {
				$assoc_list_line =~ s/assoclist //g;
				my @macs = split(' ', $assoc_list_line );
				foreach my $mac ( @macs ) {
					foreach my $station_HI ( openprint::Host_Interface->find( mac=>$mac ) ) {
						if ( (!defined $$station_HI{connected_to}) or ( uc $$station_HI{connected_to} ne uc $$HI{mac} ) ) {
							$log->debug("Updating connection of ".$station_HI->Host()->hostname() );
							$station_HI->save({connected_to=>$$HI{mac}});
						}
					} # end foreach station_HI
				} # end foreach station mac
			} else {
				$log->error("No assoc_list line from $$Host{hostname} $$HI{ip}");
			}

        }

      } else { 
        $log->error("Unknown Host type ($$Host{type})");
      } # end if
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
