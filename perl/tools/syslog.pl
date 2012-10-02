#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;
use Socket;
require IO::Socket;

require configuration;
require sql;
require ssi;
require misc;
require logger;
require openprint;
require openprint::Host;

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
	'port=s',
 );

if ($opts->{help}) {
    usage();
    exit 0;
} # end if

$log = new logger('level'=>'debug');
# Get our configuration information
if (my $err = configuration::from_file('/etc/openprint-syslog.conf')) {
    die $err;
} # end if

foreach my $param ( 'db_name','db_user','db_pass', ) {
    $config{$param} = $$opts{$param} if $$opts{$param};
    if ( ! $config{$param} ) {
        die "$program: missing required --$param parameter";
    }
} # end foreach required-param

configuration::merge($opts);
$config{port} = 514 if ! $config{port};

if ( $config{'pid_file'} ) {
    my $pidh;
    if (open($pidh, '> '.$config{'pid_file'} ) ) {
        print $pidh $$."\n";
        close($pidh);
    } else {
        die "Unable to open pid file";
    } # end if
} # end if

$log = logger->new( {'file'=>$config{'log_file'}, 'level'=>$config{'log_level'}} );
$log->info("Opening SQL connection");
$dbh = sql::open_sql( $log,
    'host'      => $config{'db_host'},
    'database'  => $config{'db_name'},
    'driver'    => 'Pg',
    'login'     => $config{'db_user'},
    'password'  => $config{'db_pass'},
);
die if ! $dbh;

my @re = (
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: pam_\w+\(sshd:auth\): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=([\._a-zA-Z0-9\-]+)\s*$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: pam_\w+\(sshd:auth\): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=([\._a-zA-Z0-9\-]+)\s+user\=\w+$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Failed password for [\._a-zA-Z0-9\-]+ from ([\._a-zA-Z0-9\-]+) port [0-9]+ ssh2$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Failed password for illegal user [\._a-zA-Z0-9\-]+ from ([\._a-zA-Z0-9\-]+) port [0-9]+ ssh2$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: error: PAM: Authentication failure for illegal user root from ([\._a-zA-Z0-9\-]+)$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: error: PAM: Authentication failure for [\._a-zA-Z0-9\-]+ from ([\._a-zA-Z0-9\-]+)$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: error: PAM: 1 more authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=([\._a-zA-Z0-9\-]+)\s+user\=\w+$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Invalid user attack from ([0-9.]+)$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Invalid user \w+ from ([0-9.]+)$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Connection closed by ([0-9.]+):? \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Received disconnect from ([0-9.]+) 11: (Bye Bye|PECL/ssh2 \(http://pecl.php.net/packages/ssh2\)) \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: User \w+ from ([0-9.]+) not allowed because not listed in AllowUsers$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: User \w+ from ([0-9.]+) not allowed because account is locked$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ proftpd\[[0-9]+\]: [\.\-A-Za-z0-9]+ \([\.\-A-Za-z0-9]+\[([.:a-zA-Z0-9]+)\]\) \- Maximum login attempts \([0-9]+\) exceeded, connection refused$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ proftpd\[[0-9]+\]: [\.\-A-Za-z0-9]+ \([\.\-A-Za-z0-9]+\[([.:a-zA-Z0-9]+)\]\) \- USER [\.\-A-Za-z0-9]+: no such user fround from [0-9.]+\[[0-9.]+\] to [.:a-zA-Z0-9]+$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Failed keyboard-interactive/pam for invalid user [\.\-A-Za-z0-9]+ from ([.:a-zA-Z0-9]+) port [0-9]+ ssh2$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ dovecot: pop3-login: Disconnected \(auth failed, 1 attempts\): user=<[a-zA-Z@\.0-9]+>, method=PLAIN, rip=([\.0-9]+), lip=[\.0-9]+(, session=<[^>]+)?$',
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ named\[[0-9]+\]: client ([0-9.]+)#[0-9]+: query \(cache\) '\./NS/IN' denied$`,
);


my %whitelist;
my $last_update = 0;

# Variables and Constants
my $MAXLEN = 1524;

# Start Listening on UDP port 514
my $sock = IO::Socket::INET->new(LocalPort => $config{port}, Proto => 'udp')||die("Socket: $@");

my $rin = '';
my $buf;
do{
	if ( ! $dbh->ping() ) {
		$dbh = sql::open_sql( $log,
				'host'      => $config{db_host},
				'database'  => $config{db_name},
				'driver'    => 'Pg',
				'login'     => $config{db_user},
				'password'  => $config{db_pass},
				);
		if ( ! $dbh ) {
			$log->error("Cannot connect to db! Sleeping");
			sleep(10);
			next;
		} # end if
	} # end if
	
	my %host_counts;
	# Every hour, we update and

	if ( $last_update < (time-3600) ) {
		$last_update = time;

		%whitelist = map{ $_->ip(), $_ } openprint::Host->find('whitelist'=>1,'ip is null'=>1);

		if ( $opts->{'blacklist'} ) {
			if ( ! open( FH, '>'.$opts->{'blacklist'} ) ) {
				die 'Unable to open blacklist: ' . $opts->{'blacklist'} . "\n";
			} else {
				foreach my $Host ( openprint::Host->find('blacklist'=>1,'order'=>'ip') ) {
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
			} # end if
			`/etc/init.d/shorewall restart`;
		} else {
			foreach my $Host ( openprint::Host->find('blacklist'=>1,order=>'ip',whitelist=>0) ) {
				my $macs = $Host->mac();
				if ( $macs and @{$macs} ) {
					foreach my $mac ( @{$macs} ) {
						$mac =~ s/:/\-/g;
						`shorewall drop ~$mac`;
					} # end foreach mac
				} elsif ( $Host->ip() ) {
					`shorewall drop $$Host{ip}`;
				} # end if
			} # end foreach Host
		} # end if
	} # end if do update

	$sock->recv($buf, $MAXLEN);
	my ($port, $ipaddr) = IO::Socket::sockaddr_in($sock->peername);
	my $hn = gethostbyaddr($ipaddr, Socket::AF_INET);
	# Without the multiline flag, will do one line at a time, nice.
	$buf=~/<(\d+)>(.*?):(.*)/;
	foreach my $re ( @re ) {
		if ( $buf =~ /$re/ ) {
			my ($when, $source) = ( $1, $2 );
			print "match for $source\n" if $opts->{debug};
			my ( $ip, $hostname );
			if ( $source =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
# Is an IP
				print "$source is an ip\n" if $opts->{debug};
				$ip = $source;
			} else {
# is a hostname
				$hostname = $source;
				$ip = gethostbyname($source);
				if ( defined $ip ) {
					$ip = Socket::inet_ntoa($ip);
					print "Got $ip for $source\n" if $opts->{debug};
				} # end if
			} # end if

			if ( $ip and $whitelist{$ip} ) {
				print "$ip is whitelisted\n" if $opts->{debug};
			} # end if
			if ( ! $ip ) {
				print "No ip for $source\n" if $opts->{debug};
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
			my $last_seen = Date::Parse::str2time( $host_counts{$ip}{updated_on} ) if $host_counts{$ip} and $host_counts{$ip}{updated_on};;
			my $occurrence = Date::Parse::str2time( $when );
#$log->warn("Last: $host_counts{$ip}{updated_on} => $last_seen, $when => $occurrence") if $host_counts{$ip};
			if ( (!$last_seen) or ($last_seen < $occurrence) ) {
				$host_counts{$ip}{'count'} += 1;
				$host_counts{$ip}{'update'} = 1;
			} else {
				print "Not counting because too old " . $host_counts{$ip}{updated_on} . " >= $when" if $opts->{debug};
			} # end if
			last;
		} # end if line matches re

	} # end foreach re

	foreach my $ip ( sort keys %host_counts ) {
		next if ! $host_counts{$ip}{update};
		if ( $host_counts{$ip}{count} > 20 ) {
			$host_counts{$ip}{blacklist} = 1;
		} # end if
		$_ = $host_counts{$ip}->save();
		if ( $_ ) {
			print $_ . "\n";
		} # end if
		print "$ip $host_counts{$ip}{ip} $host_counts{$ip}{count}\n" if $opts->{debug};
	} # end foreach ip

} while(1);

sub usage {
    print <<EOH;

usage: syslog.pl [--help] 

The purpose of this script is to monitor the AuthLog looking for attacks.

Command-line options:

    --help      Displays this message.

EOH
} # end sub usage

$dbh->disconnect();
1;
__END__
