#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;
use Sys::Syslog qw( :DEFAULT setlogsock );

use Socket;

require configuration;
require sql;
require logger;
require openprint;
require openprint::Host;
require Date::Parse;

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use File::Basename qw(basename);
use Getopt::Long ();
use Encode ();
use Data::Dumper;

my $program = basename($0);

my $opts = {};
Getopt::Long::GetOptions($opts, 'fifo=s', 'help', 'config=s',
	'log_file=s', 'log_level=s',
	'pid_file=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
	'port=s','debug=s',
);

if ($opts->{help}) {
	usage();
	exit 0;
} # end if

$log = new logger('level'=>'debug');
my %defaults = (
	port	=>	10514,
	config	=>	'/etc/openprint/syslog-apache.conf',
);
foreach my $default ( keys %defaults ) {
	$$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach default

# Get our configuration information
if (my $err = configuration::from_file($$opts{config})) {
	die $err;
} # end if
configuration::merge($opts);

foreach my $param ( 'db_name','db_user','db_pass' ) {
	die "$program: missing required --$param parameter" if ! $config{$param};
} # end foreach required-param

$log = logger->new( {'file'=>$config{'log_file'}, 'level'=>$config{'log_level'}} );
$log->info("Opening SQL connection $config{db_user} $config{db_name} on $config{db_host}");
$dbh = sql::open_sql( $log,
	host		=> $config{db_host},
	database	=> $config{db_name},
	driver		=> 'Pg',
	login	 	=> $config{db_user},
	password	=> $config{db_pass},
);
die "Couldn't connect to db: $$dbh{errstr}" if ! $dbh;
configuration::init();
configuration::from_file($$opts{config});
configuration::merge($opts);

my @re = (
);


my %whitelist;
my $last_update = 0;

setlogsock('unix');
openlog('apache', 'cons', 'pid', 'local2');

if ( $config{'pid_file'} ) {
	my $pidh;
	if (open($pidh, '> '.$config{'pid_file'} ) ) {
		print $pidh $$."\n";
		close($pidh);
	} else {
		die "Unable to open pid file";
	} # end if
} # end if

while (my $buf = <STDIN>) {
	if ( ! $dbh->ping() ) {
		$dbh = sql::open_sql( $log,
				host		=> $config{db_host},
				database	=> $config{db_name},
				driver		=> 'Pg',
				login		=> $config{db_user},
				password	=> $config{db_pass},
				);
		if ( ! $dbh ) {
			$log->error("Cannot connect to db! Sleeping");
			sleep(10);
			next;
		} # end if
		configuration::init( );
		configuration::from_file($$opts{config});
		configuration::merge($opts);
	} # end if
	
	my %host_counts;

	# Every hour, we update and
	if ( $last_update < (time-3600) ) {
		$last_update = time;

		%whitelist = ();
		foreach my $Host ( openprint::Host->find( whitelist => 1 ) ) {
			foreach my $I ( $Host->Interfaces() ) {
				next if ! $I->ip();
				$whitelist{$I->ip()} = $Host;
			} # end foreach Interfaces
		} # end foreach Host
		$openprint::log->debug(join("\n", map { 'whitelist: ' . $_ } keys %whitelist ) ) if $$opts{debug};

		# If a blacklist is specified, update it on start
		if ( $opts->{blacklist} ) {
			if ( ! open( FH, '>'.$opts->{blacklist} ) ) {
				die 'Unable to open blacklist: ' . $opts->{blacklist} . "\n";
			} else {
				foreach my $Host ( openprint::Host->find( blacklist => 1) ) {
					foreach my $Interface ( $Host->Interfaces() ) {
						my $mac = $Interface->mac();
						if ( $mac ) {
							$mac =~ s/:/\-/g;
							print FH "~$mac\n";
						} elsif ( $Interface->ip() ) {
							print FH $Interface->ip()."\n";
						} # end if
					} # end foreach Interface
				} # end foreach Host
				close(FH);
			} # end if
			`/etc/init.d/shorewall restart`;
		} elsif ( 0 ) {
			foreach my $Host ( openprint::Host->find( blacklist=>1, order=>'ip', whitelist=>0 ) ) {
				my $macs = $Host->mac();
				if ( $macs and @{$macs} ) {
					foreach my $mac ( @{$macs} ) {
						$mac =~ s/:/\-/g;
						`shorewall drop ~$mac`;
						$log->debug("Dropping !~$mac") if $config{debug};
					} # end foreach mac
				} elsif ( $Host->ip() ) {
					`shorewall drop $$Host{ip}`;
					$log->debug("Dropping $$$Host{ip}") if $config{debug};
				} # end if
			} # end foreach Host
		} # end if
		$log->debug("Done updating shorewall.") if $config{debug};
	} # end if do update

print ( $buf );
	#my ($port, $ipaddr) = IO::Socket::sockaddr_in($sock->peername);
	#my $hn = gethostbyaddr($ipaddr, Socket::AF_INET);
	$log->debug($buf) if $config{debug};
	# Without the multiline flag, will do one line at a time, nice.
	my ( $source, $remote_logname, $user, $when, $request, $server_response, $bytes, $referrer, $agent ) = $buf =~ /^(\S+) (\S+) (\S+) \[([^\]]+)\] "([^"]+)" (\d+) (\d+) "([^"]+)" "([^"]+)"$/;
	if ( ! $source ) {
		$log->error("No match: " . $buf );
		next;
	#} else {
		#$log->error("match: " . $buf );
	} 
#[error] No match: 192.168.101.10 - - [07/Feb/2013:11:22:59 -0500] "GET /css/alphacube.css HTTP/1.0" 304 282 "http://www.intelligentquote.ca/" "Mozilla/5.0 (X11; Ubuntu; Linux x86_64; rv:19.0) Gecko/20100101 Firefox/19.0"
#[debug] 127.0.0.1 - - [07/Feb/2013:11:03:00 -0500] "OPTIONS * HTTP/1.0" 200 126 "-" "Apache/2.2.22 (Ubuntu) (internal dummy connection)"
#$log->debug("Thing1: $1, thing3: $line ");

	my ( $ip, $hostname );
	if ( $source =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
# Is an IP
		$log->debug( "$source is an ip" ) if $config{debug};
		$ip = $source;
	} else {
# is a hostname
		$hostname = $source;
		$ip = gethostbyname($source);
		if ( defined $ip ) {
			$ip = Socket::inet_ntoa($ip);
			$log->debug( "Got $ip for $source" ) if $config{debug};
		} # end if
	} # end if

	if ( $ip and $whitelist{$ip} ) {
		$log->debug( "$ip is whitelisted" ) if $config{debug};
		next;
	} # end if
	if ( ! $ip ) {
		$log->debug( "No ip for $source" ) if $config{debug};
		next;
	} # end if
	if ( $ip eq '127.0.0.1' ) {
		$log->debug( "Not localhost for $source" ) if $config{debug};
		next;
	} # end if
	if ( $server_response == 404 ) {
		$log->debug("GOt 404");

		if ( ! $host_counts{$ip} ) {
			my $Interface = openprint::Host_Interface->find_one(ip=>$ip);
			if ( $Interface ) {
				my $Host = $Interface->Host();
				$host_counts{$$Interface{ip}} = $Host;
			} else {
				my $Host = $host_counts{$ip} = new openprint::Host();
				$Interface = new openprint::Host_Interface();
				$$Host{Interfaces} = [ $Interface ];
				$Host->hostname( $hostname );
				$Host->save();
				$Interface->save({ ip=>$ip, host_id=>$$Host{id} } );
			} # end if
		} # end if
		$host_counts{$ip}{count} += 1;

		if ( $host_counts{$ip}{count} > 20 and ! $host_counts{$ip}{blacklist} ) {
			$host_counts{$ip}{blacklist} = 1;
			$log->debug( "$ip $host_counts{$ip}{ip} $host_counts{$ip}{count}" ) if $opts->{debug};
			#`shorewall drop $ip` if $host_counts{$ip}{blacklist};
		} # end if
		$_ = $host_counts{$ip}->save();
		$log->error( $_ ) if $_;
	} # end if 404

} # end while buf = <STDIN>

sub usage {
	print <<EOH;

usage: syslog-apache.pl [--help] 

The purpose of this script is to monitor the AuthLog looking for attacks.

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

$dbh->disconnect() if $dbh and $dbh->ping();

closelog;

if ( $config{pid_file} ) {
	unlink $config{pid_file};
} # end if

1;
__END__
