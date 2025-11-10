#!/usr/bin/perl 
use utf8;
use lib '/var/www/testing/perl';
use strict;
use warnings;

use LWP;
use JSON;

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
    'db_port=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s', 'debug=s', 'host_id=s', 'log_level=s',
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
my $browser = LWP::UserAgent->new( ssl_opts => { verify_hostname => 0 } );
use HTTP::Cookies;
$browser->cookie_jar( HTTP::Cookies->new( file => '/tmp/cookies.txt', autosave => 1 ) );

if ( $config{site_url} ) {
	$config{siteURL} = $config{site_url};
	$config{ExternalSiteURL} = $config{site_url};
} # end if
$config{SiteTitle} = $config{site_title};
$config{SkinPath} = $config{skin_path};

$config{log_level} = 'debug' if ! $config{log_level};
$log = logger->new( { file=>$config{log_file}, level=>$config{log_level}} );

my %db_config_info = (
		port		=> $config{db_port},
		host		=> $config{db_host},
		database	=> $config{db_name},
		driver		=> 'Pg',
		login		=> $config{db_user},
		password	=> $config{db_pass},
		);
$openprint::dbh = sql::open_sql( $log, %db_config_info );
if ( ! $dbh ) {
	die "Error opening db. $!";
} # end if

require Net::Ping;
# udp has less network traffic overhead
my $p = Net::Ping->new('icmp', 10);

my @type_ids = map { $$_{id} } openprint::Host_Type->find(name=>[ 'WG602v3', 'WPN802', 'TP-Link Archer C7', 'OpenWRT' ]);

my @Hosts = $$opts{host_id} ? openprint::Host->find(id=>$$opts{host_id}) : openprint::Host->find(type_id=>\@type_ids, monitored=>1);
$log->debug('WAP polling ' . @Hosts . ' hosts.');
foreach my $Host ( @Hosts ) {
	foreach my $HI ( $Host->Interfaces() ) {
		if ( ! $HI->ip() ) {
			next;
		} # end if
		if ( !$$HI{mac} ) {
			$log->error("NO mac in HI for $$Host{id} $$Host{hostname}");
			next;
		}
		$log->debug("Pinging $$Host{hostname} at $$HI{ip}");
		my @ping = $p->ping($HI->ip());
		my $ping = $ping[0];
		if ( ! @ping ) {
			$log->warn('Problem with ping for ' . $Host->hostname() );
			next;
		} # end if

		if ($ping) {

			my $initial_url;
			my $url;
			my $args;
			my $method = 'get';
			my $protocol = 'http';

			if ( $Host->type() eq 'TP-Link Archer C7' or $Host->type() eq 'OpenWRT') {
        my $auth_key = '';

        my $rpc_auth_url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci/rpc/auth';
				my $response = $browser->post( $rpc_auth_url, 
          Content => JSON::encode_json( { method=>'login', params=>[ $Host->info('username'), $Host->info('password') ] }),
        );
        if (!$response->is_success) {
          $log->debug($response->status_line());
          if (($response->status_line() eq '307 Temporary Redirect') and ($protocol eq 'http')) {
            $protocol = 'https';
            $rpc_auth_url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci/rpc/auth';
            $response = $browser->post( $rpc_auth_url, 
              Content => JSON::encode_json( { method=>'login', params=>[ $Host->info('username'), $Host->info('password') ] }),
            );
            if (!$response->is_success and ($response->status_line() ne '403 Forbidden')) {
              $log->error("Failed talking to $$Host{hostname} at $$HI{ip} " . $response->status_line() . ' ' . $response->content() );
              next;
            }
          } elsif ($response->status_line() ne '403 Forbidden' ) {
            $log->error("Failed talking to $$Host{hostname} at $$HI{ip} " . $response->status_line() . ' ' . $response->content() );
            next;
          }
				}
        $response = get_from_json($response->content());
        if (!$response) {
          $log->warn("No response from login");
          next;
        }

        my $rpc_sys_url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci/rpc/sys';
        my $rpc_admin_url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci/rpc/admin';
        if ( $$response{result} ) {
          $auth_key = $$response{result};
          $rpc_sys_url .= '?auth='.$auth_key;
        }
        $response = $browser->post($rpc_sys_url, Content => encode_json( { method=>'net.devices' } ));
        $log->debug($response->status_line());
        my @wlans;
        my $response_json = get_from_json($response->content());
        if (! $response_json) {
          $log->warn('No response from '.$response->content());
          next;
        }
        if ( $$response_json{result} ) {
          @wlans = map { ( $_ =~ /^wlan/ ) ? $_ : () } @{$$response_json{result}};
          $log->debug("Have wlans: @wlans");
        }
        foreach my $wlan ( @wlans ) {
          $log->debug("Getting from post $rpc_sys_url $wlan");
          $response = $browser->post($rpc_sys_url, Content => encode_json( { method=>'wifi.getiwinfo', params=>[$wlan] } ));
          $response = get_from_json($response->content());
          next if ! $response;
          $log->debug( 'assoclist' . Dumper($response) );
          my $result = $$response{result};
          if ( ! $result ) {
            next;
          }
          my $assoclist = $$result{assoclist};
          next if ref $assoclist ne 'HASH';

          my $wap_HI;
          $$result{bssid} = lc $$result{bssid};

          if ( $$result{bssid} eq $$HI{mac} ) {
            $wap_HI = $HI;
          } else {
            foreach ( $Host->Interfaces() ) {
              if ( $$result{bssid} eq $$_{mac} ) {
                $wap_HI = $_;
                last;
              }
            }
          }
          if ( ! $wap_HI ) {
            $log->error("Got no wap HI for mac $$result{bssid} for wlan $wlan of $$Host{hostname}");
            next;
          }
          my @macs = keys %{$assoclist};
          update_connections( $wap_HI, @macs );
        }

        # doesn't matter which interface we communicate on so if we communicated, stop scanning.
        last;

      } elsif ( 0 ) {
				$initial_url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci';
				$url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci/admin/status/overview?status=1';
				$args = {
					luci_username=> $Host->info('username'),
					luci_password=> $Host->info('password'),
					submit => 'Login',
				};

				my $response = $browser->get( $initial_url );
				if ( ( ! $response->is_success ) and $response->status_line() ne '403 Forbidden' ) {
					$log->error("Failed talking to $$Host{hostname} at $$HI{ip} " . $response->status_line() . ' ' . $response->content() );
					next;
				}
				my $headers = $response->headers();
        foreach my $k ( keys %{$headers} ) {
          $openprint::log->debug("Header $k => $$headers{$k}");
        }
        if ( $$headers{'client-ssl-cipher'} ) {
          $protocol = 'https';
					$initial_url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci';
					$url = $protocol.'://'.$$HI{ip}.'/cgi-bin/luci/admin/status/overview?status=1&_=0.6478539785164518';
				}
#$log->debug("status: ".  $response->is_success  . ' line: ' . $response->status_line() );
#$log->debug( $response->content() );
#$log->debug( $response->as_string() );

				$response = $browser->post( $initial_url, $args );
				$headers = $response->headers();
				if ( ! $$headers{location} ) {
					$log->error("Got no location for $$Host{hostname} at $$HI{ip} from $initial_url");
				} else {
					$url = $protocol.'://'.$$HI{ip}.$$headers{location}.'/admin/status/overview?status=1';
					$response = $browser->get( $url );
					if ( ! $response->is_success ) {
						$log->error("Failed talking to $$Host{hostname} at $$HI{ip} " . $response->status_line() . ' ' . $response->content() );
						next;
					}
				}

        $log->debug("content: " . $response->content() );

				my $json = decode_json( $response->content() );
        $log->debug("content: " . Dumper($json));
				if ( $$json{wifinets} and @{$$json{wifinets}} ) {
          my %networks;

          my $assoclist;
          my @macs;

					foreach my $wifinet ( @{$$json{wifinets}} ) {
						if ( $$wifinet{networks} and @{$$wifinet{networks}} ) {
							foreach my $network ( @{$$wifinet{networks}} ) {
                $networks{$$network{ifname}} = $network;
              }
            }
          }

          $url = $protocol.'://'.$$HI{ip}.$$headers{location}.'/admin/network/wireless_assoclist';
$log->debug("Getting assoclist from $url");
          my $wireless_assoclist_response = $browser->get($url);
					if ( !$wireless_assoclist_response->is_success ) {
						$log->error("Unable to get assoclist from $$HI{ip} " . $wireless_assoclist_response->status_line());
						next;
					}
					$log->debug( 'assoclist' . $wireless_assoclist_response->content());
          $assoclist = decode_json( $wireless_assoclist_response->content() );
          $log->debug( 'assoclist' . Dumper( $assoclist ) );
          if ( $assoclist ) {
            foreach my $client ( @{$assoclist} ) {
              if ( ! $networks{$$client{ifname}} ) {
                $log->error("No network for $$client{ifname}");
              }
              if ( ! $networks{$$client{ifname}}{assoclist} ) {
                $networks{$$client{ifname}}{assoclist} = [];
              }
              push @{$networks{$$client{ifname}}{assoclist}}, $client;
            }
          }
          foreach my $network ( values %networks ) {
            my @macs = map { $$_{bssid} } @{$$network{assoclist}} if $$network{assoclist};

            my $wap_HI = $HI;
            # Older luci's didn't populate this sometimes? We are hitting the wap using one mac... but the network may have a different maac because it has multiple radios
            if ( $$network{bssid} ) {
              if ( $$HI{mac} ne lc $$network{bssid} ) {
                $log->debug( "HI{mac} $$HI{mac} ne network{bssid} $$network{bssid}");
                $wap_HI = openprint::Host_Interface->find_one( mac=>$$network{bssid} );
                if ( ! $wap_HI ) {
                  $wap_HI = new openprint::Host_Interface();
                  $wap_HI->save({mac=>$$network{bssid}, host_id=>$$Host{id}, dhcp=>1 });
                } # end if
              }
            } else {
              $log->debug("No bssid");
            }

            update_connections( $wap_HI, @macs );


          } # end ofreach network

				} else {
					$log->debug( 'No wifinets' . Dumper( $json ) );
				}

			} elsif ( $Host->type() eq 'WPN802' ) {
				use Net::SSL;
				$initial_url = 'https://'.$$HI{ip}.'/start.htm';
				$url = 'https://'.$$HI{ip}.'/DEV_device.htm';

				my $response = $browser->get($initial_url ? $initial_url : $url);
				if ( ! $response->is_success ) {
					$response = $HI->authenticate( $browser, $response, $method, '443', $url, $args );
				} # end if

				my @macs;
				my ( $assoc_list_line ) = $response->content() =~ /<tr>(.*)<\/tr>/m;
				if ( $assoc_list_line ) {
					my @lines = split( '</tr><tr>', $assoc_list_line );
					$log->debug("@ of connections: from $assoc_list_line #" . @lines );
					foreach my $line ( @lines ) {
						my ( $mac ) = $line =~ /<td align="center"><span class="thead">\d+<\/span><\/td><td align="center" noWrap><span class="ttext">([:[:xdigit:]]+)<\/span><\/td><td align="center" noWrap><span class="ttext">UNKNOWN<\/span><\/td><td align="center" noWrap><span class="ttext">Associated<\/span><\/td>/;
						push @macs, $mac if $mac;
					} # end foreach station mac
				} else {
					$log->debug("No assoc_list line from $$Host{hostname} $$HI{ip}");
				}
				# Important to log out or else no one else can access the web ui
				$response = $browser->get('https://'.$$HI{ip}.'/LGO_logout.htm');
				update_connections( $HI, @macs );

			} elsif ( $Host->type() eq 'WG602v3' ) {
				$url = 'http://'.$$HI{ip}.'/cgi-bin/stalist.html';

				my $response = $browser->get($initial_url ? $initial_url : $url);
				if ( ! $response->is_success ) {
					$response = $HI->authenticate( $browser, $response, $method, '80', $url, $args );
				}

				my @macs;
				if ( ! $response->is_success ) {
					$log->error("Should have worked. $$HI{ip} $$Host{hostname} $url ");
					$openprint::log->error( $response->status_line );
					$openprint::log->error( $response->content );
					my $headers = $response->headers();
					foreach my $k ( keys %$headers ) {
						$openprint::log->debug("Initial Header $k => $$headers{$k}");
					}  # end foreach
				} else {
					my ( $assoc_list_line ) = $response->content() =~ /var assoc_list='([^']*)';/m;
					if ( $assoc_list_line ) {
						$assoc_list_line =~ s/assoclist //g;
						@macs = split(' ', $assoc_list_line );
					} else {
						$log->debug("No assoc_list line from $$Host{hostname} $$HI{ip}");
					}
				}
				# Important to log out or else no one else can access the web ui
				$response = $browser->get('http://'.$$HI{ip}.'/cgi-bin/logout.html');
				update_connections($HI, @macs);

			} else { 
				$log->error("Unknown Host type ($$Host{type})");
			} # end if
		} else {
			$log->debug($$Host{hostname}.' is offline: ping '.$ping);
		} # end if online
	} # end foreach HI
} # end foreach $Host
$log->debug('Shutting down');
$p->close();
$dbh->disconnect() if $dbh;
exit 0;

sub update_connections {
	my ( $wap_HI, @macs ) = @_;
	openprint::Host_Interface->lock();
	my %OldConnections = map { $$_{mac} ? ( uc $$_{mac}, $_ ) : ( ) } openprint::Host_Interface->find( connected_to=>$$wap_HI{mac} );
  $log->debug("Updating @macs");
  foreach my $k ( keys %OldConnections ) {
    $log->debug("Old COnnections $k");
  }
	foreach my $mac ( map { uc $_ } @macs ) {
		if ( $OldConnections{$mac} ) {
			# Already connected

			# Theoretically this mac should only be listed once, so deleting it from the hash should leave us with a hash of disconnected clients.
			delete $OldConnections{$mac};
		} else {
			my @WIS = openprint::Host_Interface->find( mac=>$mac ) ;
			if ( ! @WIS ) {
				$log->error("No Host found for mac $mac");
				my $Host = new openprint::Host();
				$Host->save({ hostname=>$mac });
				my $HI = new openprint::Host_Interface();
				$HI->save({ host_id=>$$Host{id}, mac=>$mac, dhcp=>1 });
				push @WIS, $HI;
			}
			foreach my $station_HI ( @WIS ) {
				if ( (!defined $$station_HI{connected_to}) or ( uc $$station_HI{connected_to} ne uc $$wap_HI{mac} ) ) {
					$log->debug("Updating connection of $$station_HI{mac} ".($station_HI->Host()->hostname() ? $station_HI->Host()->hostname() : '' ). " from ".
            ( $$station_HI{connected_to} ? $$station_HI{connected_to} : '' ). " to $$wap_HI{mac}");
          $station_HI->save({connected_to=>$$wap_HI{mac}});
          (new openprint::Log())->save({action=>'Update', Object=>$station_HI->Host(),
              note=>'Connection to ' . $wap_HI->Host()->link_to() .' ' . $$wap_HI{mac}.
              ($$station_HI{connected_to} ? ' was ' . $station_HI->Host()->link_to() : '')
            });
					(new openprint::Log())->save({action=>'Update', Object=>$wap_HI->Host(),
              note=>'Connection to ' . $station_HI->Host()->link_to() });
				}
			} # end foreach station_HI
		}
	} # end foreach mac
	foreach my $mac ( keys %OldConnections ) {
		$OldConnections{$mac}->save({connected_to=>undef});
    (new openprint::Log())->save({action=>'Update', Object=>$OldConnections{$mac}->Host(), note=>'Connection to nobody on mac '.$mac });
	}
	openprint::Host_Interface->unlock();
} # end sub update_connections

sub usage {
	print <<EOH;

usage: $program [--help] 

		   The purpose of this script is to scan wireless access points and document their station lists.

		   Command-line options:

		   --help		Displays this message.
			--db_port
			--db_name
			--db_host
			--db_user
			--db_pass
			--debug
			--host_id
			--log_level

EOH
} # end sub usage

sub get_from_json {
  if (!$_[0]) {
    $log->error('No content to decode json from');
    return undef;
  }
  $log->debug($_[0]);
  my $hash;
  eval {
    $hash = JSON::decode_json($_[0]);
  };
  if ($@) {
    $openprint::log->error($@);
    return undef;
  }
  return $hash;
}

1;
__END__
