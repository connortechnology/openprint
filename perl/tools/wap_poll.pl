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
use Data::Dumper;

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
configuration::init( );
configuration::from_file( $$opts{config} );
configuration::merge( $opts );

foreach my $param ( 'db_name','db_user','db_pass' ) {
	if ( ! $openprint::config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param

use LWP::UserAgent;
use Net::SSL;
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME} = 0;
my $browser = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
use HTTP::Cookies;
$browser->cookie_jar( HTTP::Cookies->new( file => '/tmp/cookies.txt', autosave => 1 ) );

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

my @Hosts = $$opts{host_id} ? openprint::Host->find(id=>$$opts{host_id}) : openprint::Host->find(type=>[ 'WG602v3', 'WPN802', 'TP-Link Archer C7' ]);
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
			my $protocol = 'http';

			if ( $Host->type() eq 'TP-Link Archer C7' ) {
				use JSON;
				$initial_url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci';
				$url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci/;stok=7633201666a3f5dd7f25acea43449f5e/admin/status/overview?status=1&_=0.6478539785164518';
				$args = {
						'luci_username'=>'root',
						'luci_password'=>'p1GraPHic',
						'submit' => 'Login',
						
					};

				my $response = $browser->get( $initial_url );
				my $headers = $response->headers();
      #foreach my $k ( keys %{$headers} ) {
            #$openprint::log->debug("Header $k => $$headers{$k}");
        #}
	if ( $$headers{'client-ssl-cipher'} ) {
		$protocol = 'https';
				$initial_url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci';
				$url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci/;stok=7633201666a3f5dd7f25acea43449f5e/admin/status/overview?status=1&_=0.6478539785164518';
	}
  #$log->debug("status: ".  $response->is_success  . ' line: ' . $response->status_line() );
  #$log->debug( $response->content() );
  #$log->debug( $response->as_string() );

				$response = $browser->post( $initial_url, $args );
				my $headers = $response->headers();
				$url = $protocol.'://'.$$HI{ip}.$$headers{location}.'/admin/status/overview?status=1';
				my $response = $browser->get( $url );

				my $json = decode_json( $response->content() );
				if ( $$json{wifinets} and @{$$json{wifinets}} ) {
					foreach my $wifinet ( @{$$json{wifinets}} ) {
						if ( $$wifinet{networks} and @{$$wifinet{networks}} ) {
							foreach my $network ( @{$$wifinet{networks}} ) {
								if ( $$network{assoclist} ) {
									$log->debug( 'assoclist' . Dumper( $network ) );

									my $wap_HI = $HI;
									if ( $$HI{mac} ne $$network{bssid} ) {
										$wap_HI = openprint::Host_Interface->find_one( mac=>$$network{bssid} );
										if ( ! $wap_HI ) {
											$wap_HI = new openprint::Host_Interface();
											$wap_HI->save({mac=>$$network{bssid}, host_id=>$$Host{id} });
										} # end if
									}

									if ( ref $$network{assoclist} eq 'ARRAY' ) {
									foreach my $mac ( @{$$network{assoclist}} ) {
										foreach my $station_HI ( openprint::Host_Interface->find( mac=>$mac ) ) {
											if ( (!defined $$station_HI{connected_to}) or ( uc $$station_HI{connected_to} ne uc $$HI{mac} ) ) {
												$log->debug("Updating connection of ".$station_HI->Host()->hostname() );
												$station_HI->save({connected_to=>$$wap_HI{mac}});
											}
										} # end foreach station_HI
									} # end foreach mac
									} elsif ( ref $$network{assoclist} eq 'HASH' ) {
									foreach my $mac ( keys %{$$network{assoclist}} ) {
										foreach my $station_HI ( openprint::Host_Interface->find( mac=>$mac ) ) {
											if ( (!defined $$station_HI{connected_to}) or ( uc $$station_HI{connected_to} ne uc $$HI{mac} ) ) {
												$log->debug("Updating connection of ".$station_HI->Host()->hostname() );
												$station_HI->save({connected_to=>$$wap_HI{mac}});
											}
										} # end foreach station_HI
									} # end foreach mac
									}
								} else {
									$log->debug( 'No assoclist' . Dumper( $network ) );
								} # end fi assocllist
		
							} # end ofreach network
						} else {
							$log->debug( 'No networks in wifinet ' . Dumper( $wifinet  ) );
						} # end if networks
					} # end foreach wifinet

				} else {
					$log->debug( 'No wifinets' . Dumper( $json ) );
				}

			} elsif ( $Host->type() eq 'WPN802' ) {
				use Net::SSL;
				$initial_url = 'https://'.$$HI{ip}.'/start.htm';
				$url = 'https://'.$$HI{ip}.'/DEV_device.htm';

				my $response = $browser->get($initial_url ? $initial_url : $url);
				if ( ! $response->is_success ) {
					$response = $HI->authenticate( $browser, $response, $method, $url, $args );
				} # end if

				my ( $assoc_list_line ) = $response->content() =~ /<tr>(.*)<\/tr>/m;
				if ( $assoc_list_line ) {
					my @lines = split( '</tr><tr>', $assoc_list_line );
$log->debug("@ of connections: from $assoc_list_line #" . @lines );
					foreach my $line ( @lines ) {
						my ( $mac ) = $line =~ /<td align="center"><span class="thead">\d+<\/span><\/td><td align="center" noWrap><span class="ttext">([:[:xdigit:]]+)<\/span><\/td><td align="center" noWrap><span class="ttext">UNKNOWN<\/span><\/td><td align="center" noWrap><span class="ttext">Associated<\/span><\/td>/;
						if ( $mac ) {
							foreach my $station_HI ( openprint::Host_Interface->find( mac=>$mac ) ) {
								if ( (!defined $$station_HI{connected_to}) or ( uc $$station_HI{connected_to} ne uc $$HI{mac} ) ) {
									$log->debug("Updating connection of ".$station_HI->Host()->hostname() );
									$station_HI->save({connected_to=>$$HI{mac}});
								}
							} # end foreach station_HI
						} # end if mac
					} # end foreach station mac
				} else {
					$log->debug("No assoc_list line from $$Host{hostname} $$HI{ip}");
				}


      } elsif ( $Host->type() eq 'WG602v3' ) {
        $url = 'http://'.$$HI{ip}.'/cgi-bin/stalist.html';

        my $response = $browser->get($initial_url ? $initial_url : $url);
        if ( ! $response->is_success ) {
			$response = $HI->authenticate( $browser, $response, $method, $url, $args );
		}

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
				$log->debug("No assoc_list line from $$Host{hostname} $$HI{ip}");
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
