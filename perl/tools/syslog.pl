#!/usr/bin/perl 
use lib '/var/www/testing/perl';
use strict;
use Socket;
require IO::Socket;

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

my %defaults = (
	config	=>	'/etc/openprint/syslog.conf',
	port	=>	10514,
	protocol	=>	'udp',
);
foreach my $default ( keys %defaults ) {
	$$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach default

$log = new logger( {level=>'debug'} );
# Get our configuration information
if ( my $err = configuration::from_file($$opts{config}) ) {
	die $err;
} # end if
configuration::merge($opts);

foreach my $param ( 'db_name','db_user','db_pass' ) {
	die "$program: missing required --$param parameter" if ! $config{$param};
} # end foreach required-param


$log = new logger( {file=>$config{log_file}, level=>$config{log_level}} );
$log->info("Opening SQL connection");
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

@SIG{qw(HUP)} = \&sig_handler;

my @re = (
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: pam_\w+\(sshd:auth\): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=([\._a-zA-Z0-9\-]+)\s*$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: pam_\w+\(sshd:auth\): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=([\._a-zA-Z0-9\-]+)\s+user\=\w+$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Failed password for [\._a-zA-Z0-9\-]+ from ([\._a-zA-Z0-9\-]+) port [0-9]+ ssh2$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Failed password for (invalid|illegal) user [\._a-zA-Z0-9\-]+ from ([\._a-zA-Z0-9\-]+) port [0-9]+ ssh2$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: error: PAM: Authentication failure for illegal user root from ([\._a-zA-Z0-9\-]+)$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: error: PAM: Authentication failure for [\._a-zA-Z0-9\-]+ from ([\._a-zA-Z0-9\-]+)$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: error: PAM: 1 more authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=([\._a-zA-Z0-9\-]+)\s+user\=\w+$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Invalid user attack from ([0-9.]+)$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Invalid user \w+ from ([0-9.]+)$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Connection closed by ([0-9.]+):? \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Received disconnect from ([0-9.]+) 11: (Normal Shutdown, Thank you for playing|Goodbye|Bye Bye|PECL/ssh2 \(http://pecl.php.net/packages/ssh2\)) \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Received disconnect from ([0-9.]+) 10:  \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Received disconnect from ([0-9.]+) 3: com.jcraft.jsch.JSchException: (Auth cancel|reject HostKey: [0-9\.]+) \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: User \w+ from ([0-9.]+) not allowed because not listed in AllowUsers$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: User \w+ from ([0-9.]+) not allowed because account is locked$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ proftpd\[[0-9]+\]: [\.\-A-Za-z0-9]+ \([\.\-A-Za-z0-9]+\[([.:a-zA-Z0-9]+)\]\) \- Maximum login attempts \([0-9]+\) exceeded, connection refused$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ proftpd\[[0-9]+\]: [\.\-A-Za-z0-9]+ \([\.\-A-Za-z0-9]+\[([.:a-zA-Z0-9]+)\]\) \- USER [\.\-A-Za-z0-9]+: no such user found from [0-9.]+\[[0-9.]+\] to [.:a-zA-Z0-9]+$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Failed keyboard-interactive/pam for invalid user [\.\-A-Za-z0-9]+ from ([.:a-zA-Z0-9]+) port [0-9]+ ssh2$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ dovecot: pop3-login: Disconnected \(auth failed, 1 attempts\): user=<[a-zA-Z@\.0-9]*>, method=PLAIN, rip=([\.0-9]+), lip=[\.0-9]+?$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ dovecot: pop3-login: Disconnected \(auth failed, [0-9]+ attempts in [0-9]+ secs\): user=<[a-zA-Z@\.0-9]*>, method=PLAIN, rip=([\.0-9]+), lip=[\.0-9]+, session=<[^>]+$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ dovecot: pop3-login: Aborted Login \(auth failed, [0-9]+ attempts in [0-9]+ secs\): user=<[a-zA-Z@\.0-9]*>, method=PLAIN, rip=([\.0-9]+), lip=[\.0-9]+, session=<[^>]+$',
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ named\[[0-9]+\]: client ([0-9.]+)#[0-9]+: (view [A-Za-z0-9]+: )?query \(cache\) '[./[:alnum:]]+' denied$`,
);


my %whitelist;
my $last_update = 0;
my $hup;

# Variables and Constants
my $MAXLEN = 1524;

# Start Listening on UDP port 514
$log->debug("Opening $config{protocol} socket on port $config{port}") if $config{debug};
my $sock = IO::Socket::INET->new( LocalPort=>$config{port}, Proto=>$config{protocol} )||die("Socket: $@");

if ( $config{'pid_file'} ) {
	my $pidh;
	if (open($pidh, '> '.$config{'pid_file'} ) ) {
		print $pidh $$."\n";
		close($pidh);
	} else {
		die "Unable to open pid file";
	} # end if
} # end if

my $buf;
while(1) {
	if ( ! ($dbh and $dbh->ping() ) ) {
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
	} elsif ( $hup ) {
		configuration::init( );
		configuration::from_file($$opts{config});
		configuration::merge($opts);
		$log->hup();
		$hup = 0;
	} # end if
	
	my %host_counts;

	# Every hour, we update and
	if ( $last_update < (time-3600) ) {
		$last_update = time;

		%whitelist = map{ $_->ip(), $_ } openprint::Host->find( whitelist => 1, 'ip is null' => 0 );
		$openprint::log->debug(join("\n", map { 'whitelist: ' . $_->ip() } openprint::Host->find( whitelist => 1, 'ip is null' => 0 ) ) ) if $config{debug};

		# If a blacklist is specified, update it on start
		if ( $opts->{blacklist} ) {
			if ( ! open( FH, '>'.$opts->{blacklist} ) ) {
				$log->error( 'Unable to open blacklist: ' . $opts->{blacklist} );
			} else {
				foreach my $Host ( openprint::Host->find( blacklist => 1,'order'=>'ip') ) {
					my $macs = $Host->mac();
					if ( $macs and @{$macs} ) {
						foreach my $mac ( @{$macs} ) {
							$mac =~ s/:/\-/g;
							print FH "~$mac\n";
						} # end foreach mac
					} elsif ( $Host->ip() ) {
						print FH $Host->ip()."\n";
					} # end if
				} # end foreach Host
				close(FH);
				$log->warn("Having blackslist, restarting shorewall");
				`/etc/init.d/shorewall restart`;
			} # end if
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

	while( $sock->recv($buf, $MAXLEN) ) {
		next if ! $buf;
		my ($port, $ipaddr) = IO::Socket::sockaddr_in($sock->peername);
		#my $hn = gethostbyaddr($ipaddr, Socket::AF_INET);
		#$log->debug($buf) if $config{debug};
		# Without the multiline flag, will do one line at a time, nice.
		my ( $thing1, $line ) = $buf =~ /<(\d+)>(.*)/;
		if ( ! $line ) {
			$log->debug("no line for buf($buf)");
			next;
		} 
	#$log->debug("Thing1: $1, thing3: $line ");
		my $changed = 0;
		foreach my $re ( @re ) {

			#$log->debug("Checking Line: $re") if $config{debug};

			if ( $line =~ /$re/ ) {
				my ($when, $source) = ( $1, $2 );
				$log->debug( "match for source: $source\nline:$line\nre:$re") if $config{debug};
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
				next if $ip eq '172.0.0.1';

				if ( $ip and $whitelist{$ip} ) {
					$log->debug( "$ip is whitelisted" ) if $config{debug};
					last;
				} # end if
				if ( ! $ip ) {
					$log->debug( "No ip for $source" ) if $config{debug};
					next;
				} # end if

				if ( ! $host_counts{$ip} ) {
					my $Host = openprint::Host->find_one(ip=>$ip);
					if ( $Host ) {
						$host_counts{$$Host{ip}} = $Host;
					} else {
						$host_counts{$ip} = new openprint::Host();
						$host_counts{$ip}->ip( $ip );
						$host_counts{$ip}->hostname( $hostname );
					} # end if
				} # end if
				my $last_seen = Date::Parse::str2time( $host_counts{$ip}{updated_on} ) if $host_counts{$ip}{updated_on};
				my $occurrence = Date::Parse::str2time( $when );
	#$log->warn("Last: $host_counts{$ip}{updated_on} => $last_seen, $when => $occurrence") if $host_counts{$ip};
				if ( (!$last_seen) or ($last_seen < $occurrence) ) {
					$host_counts{$ip}{count} += 1;
					$host_counts{$ip}{update} = 1;
					$changed = 1;
				} else {
					$log->debug( "Not counting because too old " . $host_counts{$ip}{updated_on} . " >= $when" ) if $config{debug};
				} # end if
				last; # re
			} # end if line matches re
		} # end foreach re

		if ( $changed ) {
			foreach my $ip ( sort keys %host_counts ) {
				next if ! $host_counts{$ip}{update};
				next if $host_counts{$ip}{whitelist};
				last if ! ( $dbh and $dbh->ping() );
				if ( $host_counts{$ip}{count} > 20 ) {
					$host_counts{$ip}{blacklist} = 1;
				} # end if
				$_ = $host_counts{$ip}->save();
				if ( $_ ) {
					$log->error( $_ );
				} # end if
				$log->debug( "$ip $host_counts{$ip}{ip} $host_counts{$ip}{count}" ) if $config{debug};
				`shorewall drop $ip` if $host_counts{$ip}{blacklist};
			} # end foreach ip
			$changed = 0;
		} elsif ( $config{debug} ) {
			$log->debug("No changes for $line");
		} # end if
		last if ! ( $dbh and $dbh->ping() );
	} # end while recv

} # end while

sub sig_handler {
	my $signame = shift;
	if ( $signame eq 'HUP' ) {
		$log->info('Got HUP, re-opening log, re-reading config');
		$hup = 1;
	} # end if
	#die "Somebody sent me a SIG$signame";
} # end sub sig_handler

sub usage {
	print <<EOH;

usage: syslog.pl [--help] 

The purpose of this script is to monitor the AuthLog looking for attacks.

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

$log->debug('Disconnecting from db') if $config{debug};
$dbh->disconnect() if $dbh;

if ( $config{pid_file} ) {
	$log->debug('unlinking pid file ' . $config{pid_file}) if $config{debug};
	unlink $config{pid_file};
} # end if
$log->debug('Exiting') if $config{debug};
1;
__END__
