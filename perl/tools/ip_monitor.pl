#!/usr/bin/perl
use utf8;
use lib '/var/www/testing/perl';
use strict;
#use warnings;

require configuration;
require sql;
require misc;
require openprint::Host;
require openprint::Host_Interface;
require logger;
require openprint::Email;
require openprint::Log;
require Net::Ping;

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
	'db_port=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','blacklist=s', 'debug=s', 'config=s', 'ping_type=s',
 );

if ($opts->{help}) {
	usage();
	exit 0;
}

my %defaults = (
	config	=>	'/etc/openprint/ip_monitor.conf',
	ping_type	=>	'icmp',
);
foreach my $default ( keys %defaults ) {
	$$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach

configuration::init( );
configuration::from_file( $$opts{config} );
configuration::merge( $opts );

foreach my $param ( 'db_name','db_user','db_pass','from','recipient','smtp-server' ) {
	if ( ! $config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param

if ( $config{site_url} ) {
	$config{siteURL} = $config{site_url};
	$config{ExternalSiteURL} = $config{site_url};
} # end if
$config{SiteTitle} = $config{site_title};
$config{SkinPath} = $config{skin_path};

$config{log_level} = 'debug' if ! $config{log_level};
$log = logger->new( {'file'=>$config{log_file}, 'level'=>$config{log_level}} );

$config{sleep} = 1.0 if ! $config{sleep};

if ( $config{pid_file} ) {
	#$log->debug("Creating pid file at $config{pid_file} $$");
	my $pidh;
	if (open($pidh, '> '.$config{pid_file} ) ) {
		print $pidh $$."\n"; 
		close($pidh);
	} else {
		die 'Unable to open pid file';
	} # end if
} # end if

$config{ping_wait} = 2 if ! $config{ping_wait};
# udp has less network traffic overhead
my $p = Net::Ping->new($config{ping_type},$config{ping_wait});
my $hup;
my %times;
$SIG{HUP} = \&sig_handler;

# TUrn off Object caching
# If we do this, we incur a lot more db load which might be trivial, but.... our use of locking should mean that we don't need to do this anymore
$openprint::Object::no_cache = 0;

while(1) {
	if ( ! ( $dbh and $dbh->ping ) ) {
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
			$log->error( 'Error opening db. Sleeping for 5.' );
			sleep 5;
			next;
		} # end if ! dbh
		configuration::init( );
		configuration::from_file( $$opts{config} );
		configuration::merge( $opts );
	} elsif ( $hup ) {
		configuration::init( );
		configuration::from_file($$opts{config});
		configuration::merge($opts);
		$log->hup();
		$hup = 0;
	} # end if ! dbh

	$log->debug( "Getting hosts" );
	my @Hosts = openprint::Host->find( monitored=>1 );
	foreach my $Host ( @Hosts ) {

		$Host->lock();
		$Host->load(); # these pings can take a long time, and the record could get out of date, so refresh
		my $was_online = $Host->online();
		$log->debug( $Host->hostname() . ' was ' . ( $Host->online() ? 'online' : 'offline' ) );

		my $online = undef;
		my $now = time;

		my @HIs = $Host->Interfaces();
		foreach my $HI ( @HIs ) {
			next if ! $HI->monitor();
			if ( ! $HI->ip() ) {
				$log->debug("No ip for " . $HI->to_string() );
				next;
			}

			$log->debug( $HI->ip() . ' was ' . ( $HI->online() ? 'online' : 'offline' ) . " " . $HI->to_string() );
			my @ping = $p->ping($HI->ip());
			
			my $ping = $ping[0];
#$openprint::log->debug("Ping1: @ping");
			if ( ! @ping ) {
				$log->warn("Problem with ping for " . $Host->hostname() . ' ip: ' . $HI->ip() );
				next;
			} elsif ( $ping and ( $ping[1] > 1 ) ) {
				(new openprint::Log())->save({Object=>$Host, action=>'Long response time', ip_address=>$HI->ip(), host_id=>$$Host{id}, note=>sprintf('Response time %s seconds.<a href="/employee/it/host.html?host_id=%d">%s</a>', $ping[1], @$Host{'id','hostname'}) });
			} # end if
			$online = $ping if ! $online;

			if ( ( $HI->online() and ! $ping ) or ( $ping and !$HI->online() ) ) {
				$HI->save({online=>$ping});
			}
			$log->debug( $HI->ip() . ' is now ' . ( $HI->online() ? 'online' : 'offline' ) . ' value of ping was ' . $ping );
		} # end foreach HI

		if ( $online != $was_online ) {
			my $notified = $$Host{notified};

# Have a change, so it should get logged, only email notifications should use the offline seconds
			if ( $_ = $Host->save({online=>$online,state_changed_on=>$now,notified=>0}) ) {
				$log->error($_);
				$Host->unlock();
				next;
			} # end if	

			(new openprint::Log())->save({Object=>$Host, action_id=>( $online ? 100 : 101 ), host_id=>$$Host{id}, note=>sprintf('<a href="/employee/it/host.html?host_id=%d">%s</a>', @$Host{'id','hostname'}) });
			if ( $online and $notified ) {
# We are now online and an offline notification went out. So send an online notification
				$log->debug("Sending online notification");
				notify( $Host, $online );
			}
		} # end if ionline status change

		my $since = $now-$$Host{state_changed_on};
		$log->debug( $Host->hostname() . ' is now ' . ( $Host->online() ? 'online' : 'offline' ) . " $since " );
		if ( ( ! $Host->online() ) {
			if ( ( ! $$Host{notified} ) and ( $since > $$Host{offline_seconds} ) ) {
				$_ = $Host->save({ notified=>1 });
				if ( $_ ) {
					$log->error($_);
					$Host->unlock();
					next;
				}
				$log->warn("Sending offline notification");
				notify( $Host, $online );
			} else {
				$log->debug("Host is notified? $$Host{notified} or since($since) <= $$Host{offline_seconds}");
			}
		} # end if ! notified

		$Host->unlock();

		if ( $Host->online() ) {
			if ( $Host->type() =~ /DCS\-910/ ) {
				require LWP;
				my $browser = LWP::UserAgent->new();
				$browser->credentials( $Host->hostname().':80', 'DCS-910', $Host->info('username') => $Host->info('password') );

				my $url = 'http://'.$Host->hostname().'/IMAGE.JPG';
				$log->debug("URL: $url");
				my $response = $browser->get($url);
				if ( ! $response->is_success ) {
					if ( $response->status_line() eq '401 Unauthorized' ) {
						$log->debug("Unauthorized with " . $Host->info('username') . ' password: ' . $Host->info('password') );
						my $header = $response->header('WWW-Authenticate');
						my ( $realm ) = $header =~ /realm="(.*)"/;
						if ( $realm and ( $realm ne 'DCS-910' ) ) {
							$log->debug("Different REALM $realm");
							$browser->credentials( $Host->hostname().':80', $realm, $Host->info('username') => $Host->info('password') );
							$response = $browser->get($url);
						} # end if
					} # end if
				} # end if
				if ( ! $response->is_success ) {
					if ( $response->status_line() eq '401 Unauthorized' ) {
						$log->error("Couldn't get content from " . $url . ' unauthorized'. $response->status_line );
					} else {
						$log->warn("Couldn't get content from " . $url .' rebooting' . $response->status_line );
						my $headers = $response->headers();
						foreach my $k ( keys %$headers ) {
							$log->debug("Header $k => $$headers{$k}");
						}	# end foreach
						$Host->reboot();
					} # end if
				} else {
					$log->debug("Got content from host. Size: " . $response->content_type );
				} # end if

			} elsif ( sets::isin( $Host->type(), [ 'AIC500', 'AIC500W', 'AIC777W', 'AIC747W' ] ) ) {
				require LWP;
				my $browser = LWP::UserAgent->new();
				$browser->credentials( $Host->hostname().':80', 'Netcam', $Host->info('username') => $Host->info('password') );

				$log->debug("URL: " . $Host->hostname().'/cgi/jpg/image.cgi' );
				my $response = $browser->get('http://'.$Host->hostname().'/cgi/jpg/image.cgi');
				if ( ! $response->is_success ) {
					if ( $response->status_line() eq '401 Unauthorized' ) {
						$log->debug("Unauthorized with " . $Host->info('username') . ' password: ' . $Host->info('password') );
						my $header = $response->header('WWW-Authenticate');
						my ( $realm ) = $header =~ /realm="(.*)"/;
						if ( $realm and ( $realm ne 'Netcam' ) ) {
							$log->debug("Different REALM $realm");
							$browser->credentials( $Host->hostname().':80', $realm, $Host->info('username') => $Host->info('password') );
							$response = $browser->get('http://'.$Host->hostname().'/cgi/jpg/image.cgi');
						} # end if
					} # end if
				} # end if
				if ( ! $response->is_success ) {
					if ( $response->status_line() eq '401 Unauthorized' ) {
						$log->error("Couldn't get content from " . $Host->hostname().'/cgi/jpg/image.cgi unauthorized'. $response->status_line );
					} else {
						$log->warn("Couldn't get content from " . $Host->hostname().'/cgi/jpg/image.cgi rebooting' . $response->status_line );
						my $headers = $response->headers();
						foreach my $k ( keys %$headers ) {
							$log->debug("Header $k => $$headers{$k}");
						}	# end foreach
						$Host->reboot();
					} # end if
				} else {
					$log->debug("Got content from host. Size: " . $response->content_type );
				} # end if
			} elsif ( $Host->type() ) {
				$log->warn("nothing to do for : " . $Host->type()	. ' for host ' . $$Host{hostname}	);
			} # end if
		} # end if online
	} # end foreach Host
	sleep $config{sleep};
} # end while
$p->close();
$dbh->disconnect() if $dbh;
exit 0;

sub sig_handler {
	my $signame = shift;
	if ( $signame eq 'HUP' ) {
		$log->info('Got HUP, re-opening log, re-reading config');
		$hup = 1;
	} else {
		$log->warn("Unknown signal $signame ");
	} # end if
	#die "Somebody sent me a SIG$signame";
} # end sub sig_handler

sub notify {
	my ( $Host, $online ) = @_;
	my $results;
	my @To = map { $_->User() } $Host->Notifications();
	if ( @To and ( @To < 10 ) ) {
		my %info = ( Host	=>	$Host,);
		my $Email = new openprint::Email();
		$info{ReplacementText} = ssi::include("/email_content/host.html", \%info );

		my $html_body = ssi::include( '/email_template.html', \%info );
		my $results = (new openprint::Email())->send(
				TO			=>	\@To,
				#TO	=> 'iconnor@point-one.com',
				SUBJECT		=>	'Host has gone ' . ($online?'online':'offline') . ': ' . $Host->hostname(),
				FROM		=>	$config{TechSupportEmail},
				HTML_BODY	=>	$html_body,
				);
	} # end if @To > 10
	return $results;
}

sub usage {
	print <<EOH;

usage: iq_monitor [--help] 

The purpose of this script is to monitor hosts for uptime

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

1;
__END__
