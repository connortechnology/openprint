#!/usr/bin/perl
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
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','blacklist=s', 'debug=s', 'config=s',
 );

if ($opts->{help}) {
    usage();
    exit 0;
}

configuration::init( );
configuration::from_file( $$opts{'config'} ? $$opts{'config'} : '/etc/iq_monitor.conf' );
configuration::merge( $opts );

foreach my $param ( 'db_name','db_user','db_pass','from','recipient','smtp-server' ) {
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

$config{'sleep'} = 1.0 if ! $config{'sleep'};

if ( $config{'pid_file'} ) {
	#$log->debug("Creating pid file at $config{'pid_file'} $$");
	my $pidh;
	if (open($pidh, '> '.$config{'pid_file'} ) ) {
		print $pidh $$."\n"; 
		close($pidh);
	} else {
		die 'Unable to open pid file';
	} # end if
} # end if

$config{'ping_wait'} = 1 if ! $config{'ping_wait'};
# udp has less network traffic overhead
my $p = Net::Ping->new('icmp',$config{'ping_wait'});

my %times;

while(1) {
	if ( ! ( $dbh and $dbh->ping ) ) {
		$log->debug("Connecting to db");	
		$dbh = sql::open_sql( $log,
				'host'		=> $config{'db_host'},
				'database'	=> $config{'db_name'},
				'driver'	=> 'Pg',
				'login'		=> $config{'db_user'},
				'password'	=> $config{'db_pass'},
				);
		if ( ! $dbh ) {
			$log->error( 'Error opening db. Sleeping for 5.' );
			sleep 5;
			next;
		} # end if ! dbh
		configuration::init( );
		configuration::from_file( $$opts{'config'} ? $$opts{'config'} : '/etc/iq_monitor.conf' );
		configuration::merge( $opts );
	} # end if ! dbh

	$log->debug( "Getting hosts" );
	my @Hosts = openprint::Host->find('monitored'=>1);
	$log->debug( 'Monitoring ' . @Hosts . ' hosts.' );
	foreach my $Host ( @Hosts ) {
		if ( ! $Host->ip() ) {
			$log->debug( "Monitored host without ip: " . $Host->to_string() );
			next;
		} # end if
		$log->debug( $Host->hostname() . ' is ' . ( $Host->online() ? 'online' : 'offline' ) );
		my @ping = $p->ping($Host->ip());
		my $ping = $ping[0];
#$openprint::log->debug("Ping1: @ping");
		if ( ! @ping ) {
			$log->warn("Problem with ping for " . $Host->hostname() );
			next;
		} elsif ( $ping and ( $ping[1] > 1 ) ) {
			(new openprint::Log())->save({'action'=>'reboot', 'ip_address'=>$Host->ip(), 'note'=>sprintf('Response time %s seconds.<a href="/employee/it/host.html?host_id=%d">%s</a>', $ping[1], @$Host{'id','hostname'}) });
		} # end if

		if ( $Host->online() != $ping ) {
			my $last_changed_on = $$Host{'state_changed_on'};

			# Have a change, so it should get logged, only email notifications should use the offline seconds
			if ( $_ = $Host->save({'online'=>$ping,'state_changed_on'=>time,'notified'=>0}) ) {
				$log->error($_);
				next;
			} # end if	
			
			(new openprint::Log())->save({'action_id'=>( $ping ? 100 : 101 ), 'ip_address'=>$Host->ip(), 'note'=>sprintf('<a href="/employee/it/host.html?host_id=%d">%s</a>', @$Host{'id','hostname'}) });
			$log->debug( $Host->hostname() . ' is now ' . ( $Host->online() ? 'online' : 'offline' ) );

			if ( ( $ping and (time-$last_changed_on > $$Host{'offline_seconds'}) ) or ( ! $$Host{'offline_seconds'} ) ) {
$log->warn("BLAH should be 0 $ping $$Host{'offline_seconds'}");
				# Do immediate notifications
				my @To = map { $_->User() } $Host->Notifications();
				if ( @To and ( @To < 10 ) ) {
					my $results = (new openprint::Email())->send(
							'TO'	=>	\@To,
							'SUBJECT'	=>	'Host has gone ' . ($ping?'online':'offline') . ': ' . $Host->hostname() . ' ' . (time-$last_changed_on) . ' seconds ago.',
							'FROM'		=>	$config{'TechSupportEmail'},
							'BODY'		=>	"
							IP: $$Host{ip}
Description: $$Host{'description'}

Please investigate.",
);
				} # end if to < 10
			} # end if immediate notifications
		} elsif ( $Host->offline_seconds() and ( ! $ping ) and ( ! $$Host{'notified'} ) ) {
			if ( time - $$Host{'state_changed_on'} > $$Host{'offline_seconds'} ) {
				$Host->save({'notified'=>1});
				my @To = map { $_->User() } $Host->Notifications();
				if ( @To and ( @To < 10 ) ) {
					my $results = (new openprint::Email())->send(
							'TO'	=>	\@To,
							'SUBJECT'	=>	'Host has gone ' . ($ping?'online':'offline') . ': ' . $Host->hostname(),
							'FROM'		=>	$config{'TechSupportEmail'},
							'BODY'		=>	"
							IP: $$Host{ip}
Description: $$Host{'description'}

Please investigate.",
);
				} # end if @To > 10
			} # end if offline_seconds
		} # end if online != ping

		if ( $Host->online() ) {
			if ( sets::isin( $Host->type(), [ 'AIC500', 'AIC500W', 'AIC777W', 'AIC747W' ] ) ) {
				my $browser = LWP::UserAgent->new();
				$browser->credentials( $Host->hostname().':80', 'Netcam', 'admin'=>'p1GraPHic' );

				$log->debug("URL: " . $Host->hostname().'/cgi/jpg/image.cgi' );
				my $response = $browser->get('http://'.$Host->hostname().'/cgi/jpg/image.cgi');
				if ( ! $response->is_success ) {
					if ( $response->status_line() eq '401 Unauthorized' ) {
						my $header = $response->header('WWW-Authenticate');
						my ( $realm ) = $header =~ /realm="(.*)"/;
						if ( $realm and $realm ne 'Netcam' ) {
							$browser->credentials( $Host->hostname().':80', $realm, 'admin'=>'p1GraPHic' );
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
						}  # end foreach
						$response = $browser->get('http://'.$Host->hostname().'/admin/reboot.cgi?type=0');
						$log->debug($response->is_success);
						(new openprint::Log())->save({'action_id'=>102, 'ip_address'=>$Host->ip(), 'note'=>sprintf('<a href="/employee/it/host.html?host_id=%d">%s</a> has been rebooted.', @$Host{'id','hostname'})});
						my @To = map { $_->User() } $Host->Notifications();
						if ( @To and ( @To < 10 ) ) {
							$log->debug("Emailing: " . join(',', map { $_->email() } @To ) );
							my $results = (new openprint::Email())->send(
									'TO'	=>	\@To,
									'SUBJECT'	=>	'Camera rebooted ' . $Host->hostname(),
									'FROM'		=>	$config{'TechSupportEmail'},
									'BODY'		=>	"
	IP: $$Host{ip}
	Description: $$Host{'description'}
	",
									);
						} # end if
					} # end if
				} else {
					$log->debug("Got content from host. Size: " . $response->content_type );
				} # end if
			} elsif ( $Host->type() ) {
				$log->warn("unsupported type: " . $Host->type() );
			} # end if
		} # end if online
	} # end foreach $Host
	sleep $config{'sleep'};
} # end while
$p->close();
$dbh->disconnect() if $dbh;
exit 0;

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
