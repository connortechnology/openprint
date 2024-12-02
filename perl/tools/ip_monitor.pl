#!/usr/bin/perl
use utf8;
use lib '/var/www/testing/perl';
use strict;
use warnings;

require openprint;
require configuration;
require sql;
require misc;
require openprint::User;
require openprint::Host;
require openprint::Host_Interface;
require openprint::Host_Config;
require logger;
require openprint::Email;
require openprint::Log;
require Net::Ping;
require Net::IP;
require HTML::FormatText;
require Time::HiRes;

use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
$openprint::log = logger->new();
$log->{level} = 'debug';

use Getopt::Long;
use File::Basename qw(basename);

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help', 
	'db_port=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
	'blacklist=s', 'debug=s', 'config=s', 'ping_type=s', 'host_type=s',
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

configuration::init();
configuration::from_file($$opts{config});
configuration::merge($opts);

foreach my $param ( 'db_name','db_user','db_pass','from','recipient','smtp_server' ) {
	if ( ! $openprint::config{$param} ) {
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
$p->hires();
my %last_ping_time;

my $hup;
$SIG{HUP} = \&sig_handler;

# Turn off Object caching
# If we do this, we incur a lot more db load which might be trivial, but.... our use of locking should mean that we don't need to do this anymore
$openprint::Object::no_cache = 0;
$openprint::Object::no_cache = 0;

$openprint::dbh = sql::open_sql( $log,
		port		=> $config{db_port},
		host		=> $config{db_host},
		database	=> $config{db_name},
		driver		=> 'Pg',
		login		=> $config{db_user},
		password	=> $config{db_pass},
		);
if ( ! $dbh ) {
	$log->error( 'Error opening db. Sleeping for 5.' );
	die;
} # end if ! dbh
configuration::from_db( );
configuration::from_file($$opts{config});
configuration::merge($opts);

if ( $config{user_id} ) {
	$openprint::session{user_id} = $config{user_id};
	$openprint::User = new openprint::User($openprint::session{user_id});
	$openprint::session{company_id} = $openprint::User->company_id();
	$openprint::Company = $openprint::User->Company();
	$openprint::Company = $openprint::User->Company();
}

# Indexed by Host Id
my %configurations;
my %status;

while(1) {
  if ( ! ( $dbh and $dbh->ping ) ) {
    $openprint::dbh = sql::open_sql($log,
      port	  	=> $config{db_port},
      host	  	=> $config{db_host},
      database	=> $config{db_name},
      driver		=> 'Pg',
      login	  	=> $config{db_user},
      password	=> $config{db_pass},
    );
    if ( !$dbh ) {
      $log->error('Error opening db. Sleeping for 5.');
      sleep 5;
      next;
    } # end if !dbh
    configuration::init();
    configuration::from_file($$opts{config});
    configuration::merge($opts);
  } elsif ( $hup ) {
    configuration::init();
    configuration::from_file($$opts{config});
    configuration::merge($opts);
    $log->hup();
    $hup = 0;
  } # end if !dbh

	my $Network_Type = openprint::Host_Type->find_one(name=>'Network');
	my $Network;
	my @host_ids;
	if ( $Network_Type && $config{network} ) {
		$Network = openprint::Host->find_one(type_id=>$$Network_Type{id}, hostname=>$config{network});	
		if ( !$Network ) {
			$log->error("Failed to find network $config{network}");
			die;
		}
		$log->debug($Network->to_string());
		my @Network_Interfaces = $Network->Interfaces();
		foreach my $HI ( $Network->Interfaces() ) {
			push @host_ids, map { $_->host_id() } openprint::Host_Interface->find('ip <<=' => $$HI{ip});
		}
		if ( !@host_ids ) {
			$log->error("Failed to find any hosts in network $config{network}");
			die;
		}
	}
	my @Hosts = openprint::Host->find(monitored=>1,
			( $$opts{host_type} ? ( type=>$$opts{host_type} ) : () ),
			( @host_ids ? ( id=>\@host_ids ) : () ),
			);
  foreach my $Host ( @Hosts ) {
    #$log->debug('host '.($Host->hostname()?$Host->hostname():'with no hostname').' was '.($Host->online() ? 'online' : 'offline'));

    my $online = undef;
    my $now = time;
    my $has_monitored_interfaces = 0;

    if (!$$Host{id}) {
      $log->error("How can we have a host with no id?! $Host $$Host{id} ".$Host->to_string());
      next;
    }
    # If we have a minimum frequency set and not enough time has passed, then skip it.
    if ( $$Host{min_ping_frequency} and $last_ping_time{$$Host{id}} and ( ($now - $last_ping_time{$$Host{id}}) < $$Host{min_ping_frequency} ) ) {
      #$log->debug("min_ping_frequency is $$Host{min_ping_frequency} and now - last_ping_time($last_ping_time{$$Host{id}}) = " . ($now - $last_ping_time{$$Host{id}}) . " < $$Host{min_ping_frequency}" );
      next;
    }
    $last_ping_time{$$Host{id}} = $now;

    # First find out current status, then lock & load to find out previous 
    # status because we don't want to hold this lock for however long it takes to ping.
    my @HIs = $Host->Interfaces(undef);
    my %hi_status;
    foreach my $HI ( @HIs ) {
      $HI->load(); # Refresh in case something has changed
      next if ! $HI->monitor();
      if ( ! $HI->ip() ) {
        $log->debug('No ip for '.$HI->to_string());
        if ( $HI->online() ) {
          $HI->load(); # Get any updates that aren't in cache
          $HI->save({online=>0});
        }
        next;
      }

      $has_monitored_interfaces = 1;
      my $ip = new Net::IP($HI->ip());
      do { # foreach ip

        $log->debug($ip->ip().' was '.( $HI->online() ? 'online' : 'offline' ).' '.$HI->to_string());
        my @ping = $p->ping($ip->ip());

        if ( ! @ping ) {
          $log->warn('Problem with ping for '.$Host->hostname().' ip: '.$ip->ip());
          next;
        } 

        my ($ping, $duration, undef) = @ping;
        if ( $ping and $HI->is_subnet() ) {
          if ( ! openprint::Host_Interface->find_one(ip=>$ip->ip()) ) {

            my $new_HI = $HI->copy();
            $$new_HI{ip} = $ip->ip();

            my $mac = $new_HI->get_mac();
            if ( $mac and (my $existing_HI = openprint::Host_Interface->find_one(mac=>$mac) )) {
              (new openprint::Log())->save( {
                  Object  => $existing_HI->Host(),
                  note  => "IP Address changed from $$existing_HI{ip} to $$new_HI{ip} by ip_monitor subnet scanning.",
                  action  => 'IP Changed'
                } );
              $existing_HI->save({ip=>$ip->ip()});

            } else {
              # We are pinging a subnet, so now we duplicate the to create a new entry for this ip
              my $new_Host = $HI->Host()->copy();

              $new_Host->save({hostname=>$Host->hostname().' '.$ip->ip(), type_id=>undef});
              $new_HI->save({host_id=>$$new_Host{id}});
              foreach my $N ( $Host->Notifications() ) {
                $N->copy()->save({host_id=>$$new_Host{id}});
              }
              # Send notification?
              notify_new_host_detected($new_Host);
            }
          }
          next;
        } # end if is_subnet

        if ( $ping and ( $duration > ($$Host{max_ping_time} ? $$Host{max_ping_time} : 1 ) ) ) {
          (new openprint::Log())->save({
              Object=>$Host,
              action=>'Long response time',
              ip_address=>$HI->ip(),
              host_id=>$$Host{id},
              note=>sprintf('Response time %.3f seconds.<a href="/employee/it/host.html?host_id=%d">%s</a>', 1000000*$duration, @$Host{'id','hostname'}),
            });
        } # end if

        # The idea is if any ip is pingable... then the host is up
        $online = $ping if ! $online;
        $hi_status{$HI->ip()} = $ping;

        if ( ( $HI->online() and ! $ping ) or ( $ping and !$HI->online() ) or !defined($$HI{online})) {
          $HI->load(); # Get any updates that aren't in cache
          $HI->save({online=>$ping});
        }
        $log->debug( $HI->ip() . ' is now ' . ( $HI->online() ? 'online' : 'offline' ) . ' value of ping was ' . ( defined $ping ? $ping : 'undef' ) );
      } while (++$ip); # end foreach ip
    } # end foreach HI

    if ( ! $has_monitored_interfaces ) {
      $log->error("Host $$Host{hostname} is monitored but none of it's interfaces are.");
      next;
    }
    if ( ! defined $online ) {
      # No information
      $log->error("Unable to ping $$Host{id} $$Host{hostname}");
      next;
    }

    $Host->lock();
    $Host->load(); # these pings can take a long time, and the record could get out of date, so refresh
    my $was_online = $Host->online();
    if ( ( ! defined $was_online) or ($online != $was_online) ) {
      my $notified = $$Host{notified};

      # Have a change, so it should get logged, only email notifications should use the offline seconds
      if ( $_ = $Host->save({online=>$online,state_changed_on=>$now,notified=>0}) ) {
        $log->error($_);
        $Host->unlock();
        next;
      } # end if	

      (new openprint::Log())->save({
          Object=>$Host,
          action_id=>( $online ? 100 : 101 ),
          host_id=>$$Host{id},
          note=>sprintf('<a href="/employee/it/host.html?host_id=%d">%s</a>', @$Host{'id','hostname'}) . join(', ', 'interface status:' , map { $_.': '.($hi_status{$_}?'online':'offline') } keys %hi_status)
        });
      if ( $online and $notified ) {
        # We are now online and an offline notification went out. So send an online notification
        $log->debug("Sending online notification");
        notify( $Host, $online );
      }
    } else {
      if ( (!$online) and $$Host{notify_frequency} and ((!$$Host{state_changed_on}) or ($$Host{notify_frequency} < ( $now - $$Host{state_changed_on} )))) {
        $log->debug("( ! $online ) and $$Host{notify_frequency} and ( $$Host{notify_frequency} < ( $now - $$Host{state_changed_on}-$now ) ) " . ($now-$$Host{state_changed_on} ));
        notify( $Host, $online );
        $Host->save({ state_changed_on => $now });
      }
    } # end if online status change

    my $since = $now-($$Host{state_changed_on} ? $$Host{state_changed_on} : 0 );
    $log->debug( ($Host->hostname() ? $Host->hostname() : 'unknown hostname'). ' is now ' . ( $Host->online() ? 'online' : 'offline' ) . " $since seconds ago" );
    if ( ! $Host->online() ) {
      if ( ( ! $$Host{notified} ) and ( (!$$Host{offline_seconds}) or ( $since > $$Host{offline_seconds} ) ) ) {
        $_ = $Host->save({ notified=>1 });
        if ( $_ ) {
          $log->error($_);
          $Host->unlock();
          next;
        }
        $log->warn("Sending offline notification");
        notify( $Host, $online );
        #} else {
        #$log->debug("Host is notified? $$Host{notified} or since($since) <= $$Host{offline_seconds}");
      }
    } # end if ! notified

    $Host->unlock();

    if ( $Host->online() and $$Host{type_id} ) {

      if ( $Host->can_get_config() ) {
        my %host_config = $Host->get_config();
        if ( %host_config and misc::compare_hash(\%host_config, $configurations{$$Host{id}}) ) {
          (new openprint::Host_Config())->save({host_id=>$$Host{id}, data=>\%host_config, name=>'config'});
          $configurations{$$Host{id}} = \%host_config;
        }
        my %host_status = $Host->get_status();
        if ( %host_status and misc::compare_hash(\%host_status, $status{$$Host{id}}) ) {
          (new openprint::Host_Config())->save({host_id=>$$Host{id}, data=>\%host_status, name=>'status'});
          $status{$$Host{id}} = \%host_status;
        }
      }

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

  if ( $config{sleep} ) {
    $log->debug("Sleeping for $config{sleep} seconds");
    sleep $config{sleep};
  } else {
    $log->debug("Not Sleeping");
  }
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
  my @To = map { $_->User() } $Host->Notifications(undef);
  if ( @To and ( @To < 10 ) ) {
    my %info = ( Host	=>	$Host,);
    my $Email = new openprint::Email();
    $info{ReplacementText} = ssi::include('/email_content/host.html', \%info);
    my $text_body = HTML::FormatText->format_string($info{ReplacementText});

    my $html_body = ssi::include('/email_template.html', \%info);
    $results .= $Email->send(
      TO			  =>	\@To,
      SUBJECT		=>	'Host has gone ' . ($online?'online':'offline') . ': ' . $Host->hostname(),
      FROM	  	=>	$config{TechSupportEmail},
      BODY      =>  $text_body,
      HTML_BODY	=>	$html_body,
    );
    (new openprint::Log())->save({ Object=>$Host, action=>'Emailed', note=>$results });
  } # end if @To > 10
  return $results;
}
sub notify_new_host_detected {
  my ( $Host ) = @_;
  my $results;
  my @To = map { $_->User() } $Host->Notifications(undef);
  if ( @To and ( @To < 10 ) ) {
    my %info = ( Host	=>	$Host,);
    my $Email = new openprint::Email();
    $info{ReplacementText} = ssi::include('/email_content/host_detected.html', \%info);

    my $html_body = ssi::include('/email_template.html', \%info);
    $results .= (new openprint::Email())->send(
      TO		  	=>	\@To,
      SUBJECT		=>	'New Host has been detected : ' . $Host->hostname(),
      FROM	  	=>	$config{TechSupportEmail},
      HTML_BODY	=>	$html_body,
    );
    (new openprint::Log())->save({ Object=>$Host, action=>'Emailed', note=>$results });
  } # end if @To > 10
  return $results;
}

sub usage {
  print <<EOH;

usage: ip_monitor [--help] 

The purpose of this script is to monitor hosts for uptime

Command-line options:

  --help		Displays this message.

EOH
} # end sub usage

1;
__END__
