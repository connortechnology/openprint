#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;
use warnings;
use Socket;
require IO::Socket;

require configuration;
require sql;
require logger;
require openprint;
require openprint::Host;
require openprint::Log;
require Date::Parse;
require DateTime;
require DateTime::Format::Pg;

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
	'pid_file=s', 'db_port=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
	'port=s','debug=s',
	'reload=s',
);

if ($opts->{help}) {
	usage();
	exit 0;
} # end if

my %defaults = (
	config  	=>	'/etc/openprint/syslog.conf',
	port    	=>	10514,
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
	die "$program: missing required --$param parameter" if ! $openprint::config{$param};
} # end foreach required-param


$log = new logger( {file=>$config{log_file}, level=>$config{log_level}} );
my %db_connect_info = (
	port		=> $config{db_port},
	host		=> $config{db_host},
	database	=> $config{db_name},
	driver		=> 'Pg',
	login	 	=> $config{db_user},
	password	=> $config{db_pass},
);

$openprint::dbh = sql::open_sql( $log, %db_connect_info );
die "Couldn't connect to db: $$dbh{errstr}" if ! $dbh;
configuration::init();
configuration::from_file($$opts{config});
configuration::merge($opts);

@SIG{qw(HUP)} = \&sig_handler;
my @re = (
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: pam_\w+\(sshd:auth\): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=(?<IP>[:\._a-zA-Z0-9\-]+)\s*',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Bad (remote )?protocol version identification \'[^\']+\' from (?<IP>[:\._a-zA-Z0-9\-]+)( port [[:digit:]]+)?$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Did not receive identification string from (?<IP>[:\._a-zA-Z0-9\-]+)( port [[:digit:]]+)?$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: pam_\w+\(sshd:auth\): authentication failure; logname= uid=0 euid=0 tty=ssh ruser= rhost=(?<IP>[:\._a-zA-Z0-9\-]+)(\s+user\=\w+)?$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: (fatal: )?Unable to negotiate with (?<IP>[:\._a-zA-Z0-9\-]+) port [0-9]+',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Failed password for [\._a-zA-Z0-9\-]+ from (?<IP>[:\._a-zA-Z0-9\-]+) port [0-9]+ ssh2$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Failed password for (invalid|illegal) user .+? from (?<IP>[:\._a-zA-Z0-9\-:]+) port [0-9]+ ssh2$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: fatal: Timeout before authentication for (?<IP>[:\._a-zA-Z0-9\-:]+) port [0-9]+ ssh2$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: error: PAM: Authentication failure for (illegal user root|[\._a-zA-Z0-9\-]+) from (?<IP>[:\._a-zA-Z0-9\-:]+)$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: (error: )?PAM: [[:digit:]]+ more authentication failures?; logname= uid=0 euid=0 tty=ssh ruser= rhost=(?<IP>[:\._a-zA-Z0-9\-:]+)(\s+user=\w+)?$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Disconnecting: Too many authentication failures for (invalid user )?[^[:space:]]* from (?<IP>[.:[:xdigit:]]+) port [[:digit:]]+ ssh2 \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: (Connection (closed|reset) by|Disconnected from) ((authenticating|invalid) user [.@ [:alnum:]]+? )?(?<IP>[.:[:xdigit:]]+)( port [[:digit:]]+)?( \[preauth\])?$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Disconnecting ((authenticating|invalid) )? user [[:alnum:]]* (?<IP>[.:[:xdigit:]]+) port [[:digit:]]+: Change of username or service not allowed:',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: error: maximum authentication attempts exceeded for (invalid user )?[[:alnum:]]+ from (?<IP>[.:[:xdigit:]]+) port [[:digit:]]+ ssh2 \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Invalid user \S* from (?<IP>[.:[:xdigit:]]+)',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Connection closed by (?<IP>[.:[:xdigit:]]+):? \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Received disconnect from (?<IP>[.:[:xdigit:]]+) (port [[:digit:]]+:)?[[:digit:]]+:[ \.,/:[:alnum:]]+\[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Protocol major versions differ for (?<IP>[.:[:xdigit:]]+) ',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: User \w+ from (?<IP>[.:[:xdigit:]]+) not allowed because (account is locked|not listed in AllowUsers)$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: ssh_dispatch_run_fatal: Connection from (?<IP>[.:[:xdigit:]]+) port [[:digit:]]+: message authentication code incorrect \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: ssh_dispatch_run_fatal: Connection from (?<IP>[.:[:xdigit:]]+) port [[:digit:]]+: Connection corrupted \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: ssh_dispatch_run_fatal: Connection from (?<IP>[.:[:xdigit:]]+) port [[:digit:]]+: Connection corrupted \[preauth\]$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: banner exchange: Connection from (?<IP>[\.:[:xdigit:]]+) port [[:digit:]]+: invalid format$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ proftpd\[[0-9]+\]: [\.\-A-Za-z0-9]+ \([\.\-A-Za-z0-9]+\[(?<IP>[.:a-zA-Z0-9]+)\]\) \- Maximum login attempts \([0-9]+\) exceeded, connection refused$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ proftpd\[[0-9]+\]: [\.\-A-Za-z0-9]+ \([\.\-A-Za-z0-9]+\[(?<IP>[.:a-zA-Z0-9]+)\]\) \- USER [\.\-A-Za-z0-9]+: no such user found from [0-9.]+\[[0-9.]+\] to [.:a-zA-Z0-9]+$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ sshd\[[0-9]+\]: Failed keyboard-interactive/pam for invalid user [\.\-A-Za-z0-9]+ from (?<IP>[.:a-zA-Z0-9]+) port [0-9]+ ssh2$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ dovecot: (imap|pop3)\-login: Disconnected (Too many (bad|invalid) commands )?\((no auth|auth failed, [0-9]+) attempts( in [0-9]+ secs)?\): user=<[^>]*>, (method=PLAIN, )?rip=(?<IP>[\.0-9]+), lip=[\.0-9]+(, session=<[^>]+>)?$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ dovecot: (imap|pop3)\-login: Disconnected \(((auth failed, [0-9]+|no) attempts in|client didn\'t finish SASL auth, waited) [0-9]+ secs\): user=<[a-zA-Z@\.0-9]*>, (method=PLAIN, )?rip=(?<IP>[\.0-9]+), lip=[\.0-9]+',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ dovecot: pop3\-login: Aborted (l|L)ogin \(auth failed, [0-9]+ attempts in [0-9]+ secs\): user=<[a-zA-Z@\.0-9]*>, method=PLAIN, rip=(?<IP>[\.0-9]+), lip=[\.0-9]+, session=<[^>]+>$',
		'^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ dovecot: imap\-login: Aborted (l|L)ogin \(client didn\'t finish SASL auth, waited 0 secs\): user=<[a-zA-Z@\.0-9]*>, method=[[:alnum:]-]+, rip=(?<IP>[\.0-9]+), lip=[\.0-9]+, session=<[^>]+>$',
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ named\[[0-9]+\]: client (?<IP>[.:[:xdigit:]]+)#[0-9]+: (view [A-Za-z0-9]+: )?query \(cache\) '[./[:alnum:]]+' denied$`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ pam\-abl\[[0-9]+\]: Blocking access from (?<IP>[.:[:xdigit:]]+) to service sshd, user root$`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ postfix\/(submission\/)?smtpd\[[0-9]+(\]:)? warning: [\.\-A-Za-z0-9]+\[(?<IP>[.:[:xdigit:]]+)\]: SASL (CRAM\-MD5|Login|LOGIN|PLAIN) authentication fail`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ postfix\/(submission\/)?smtpd\[[0-9]+(\]:)? warning: non\-SMTP command from unknown\[(?<IP>[.:[:xdigit:]]+)\]:`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ postfix\/smtpd\[[0-9]+\]: warning: Connection rate limimt exceeded: [[:digit:]]+ from unknown \[(?<IP>[.:[:xdigit:]]+)\] for service smtp$`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ pdns(_server)?\[[0-9]+\]: Received a malformed qdomain from (?<IP>[.:[:xdigit:]]+), '[^']+': sending servfail$`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ pdns_server\[[0-9]+\]: TCP Connection Thread died because of network error: Error reading DNS data from TCP client (?<IP>[.[:digit:]]{7,15}): Timeout reading data$`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ ovpn\-server\[[0-9]+\]: (?<IP>[.:[:xdigit:]]+):[0-9]+ WARNING Bad encapsulated packet length from peer \([[:digit:]]+\), which must be > 0 and <= 1547 \-\- please ensure that \-\-tun\-mtu or \-\-link\-mtu is equal on both peers \-\- this condition could also indicate a possible active attack on the TCP link \-\- \[Attempting restart\.\.\.\]$`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ ovpn\-[[:alnum:]]+\[[0-9]+\]: (?<IP>[.:[:xdigit:]]+):[0-9]+ TLS Error: TLS handshake failed$`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ kernel: \[[0-9]+\.[0-9]+\] Shorewall:logflags:DROP:IN=[a-z]+[0-9] OUT= MAC= SRC=(?<IP>[.:[:xdigit:]]+) DST=[0-9\.]+ LEN=40 TOS=0x00 PREC=0x00 TTL=[0-9]+ ID=[0-9]+ DF PROTO=TCP SPT=443 DPT=21 WINDOW=8192 RES=0x00 URGP=0$`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ kernel: \[[0-9]+\.[0-9]+\] Shorewall:logflags:DROP:IN=[a-z]+[0-9] OUT= MAC= SRC=(?<IP>[.:[:xdigit:]]+)`,
		q`^(\w{3} [ :0-9]{11}) [\._a-zA-Z0-9\-]+ apache2: \[:error\] \[pid [0-9]+\] \[client (?<IP>[.:[:xdigit:]]+):[0-9]+\] script '[/\.\-[:alnum:]]+\.php' not found or unable to stat`,
);


my %whitelist;
my $last_update = 0;
my $hup;
my %hostname_lookups;
my $parser = 'DateTime::Format::Pg';

# Variables and Constants
my $MAXLEN = 1524;

# Start Listening on UDP port 514
$log->debug("Opening $config{protocol} socket on port $config{port}") if $openprint::config{debug};
my $sock = IO::Socket::INET->new( LocalPort=>$config{port}, Proto=>$config{protocol} )||die("Socket: $@");

if ( $config{pid_file} ) {
	my $pidh;
	if (open($pidh, '> '.$config{pid_file})) {
		print $pidh $$."\n";
		close($pidh);
	} else {
		die "Unable to open pid file";
	} # end if
} # end if

my $buf;
my %host_counts;

while(1) {
	if ( ! ($dbh and $dbh->ping() ) ) {
		$dbh = sql::open_sql( $log, %db_connect_info );
		if ( ! $dbh ) {
			$log->error("Cannot connect to db! Sleeping");
			sleep(10);
			next;
		} # end if
		configuration::init( );
		configuration::from_file($$opts{config});
		configuration::merge($opts);
	} elsif ( $hup ) {
		$log->hup();
    $log->debug("# of entries in host_counts: " . keys %host_counts);
		configuration::init( );
		configuration::from_file($$opts{config});
		configuration::merge($opts);
		$hup = 0;
	} # end if
	
	# Every hour, we update and
	if ( $last_update < (time-3600) ) {
		$last_update = time;
		%host_counts = ();
		%hostname_lookups = ();

		my @WhiteList_Hosts = openprint::Host->find( whitelist=>1 );
		%whitelist = map{ $_->ip() => $_ } openprint::Host_Interface->find(
				'ip is null'=>0,
				host_id=>[ map { $$_{id} } @WhiteList_Hosts ]
				) if @WhiteList_Hosts;
		$openprint::log->debug(join("\n", map { 'whitelist: ' . $_ } keys %whitelist ) ) if $config{debug};

		# If a blacklist is specified, update it on start
		if ( $opts->{blacklist} ) {
			if ( ! open( FH, '>'.$opts->{blacklist} ) ) {
				$log->error( 'Unable to open blacklist: ' . $opts->{blacklist} );
			} else {
				foreach my $Host ( openprint::Host->find( blacklist => 1) ) {
					foreach my $Interface ( $Host->Interfaces() ) {
						if ( $Interface->mac() ) {
							my $mac = $Interface->mac();
							$mac =~ s/:/\-/g;
							print FH "~$mac\n";
						} elsif ( $Interface->ip() ) {
							print FH $Interface->ip()."\n";
						} # end if
					} # end foreach mac
				} # end foreach Host
				close(FH);
				$log->warn("Having blackslist, restarting shorewall");
				`/etc/init.d/shorewall restart`;
			} # end if
		} elsif ( 0 ) {
			foreach my $Host ( openprint::Host->find( blacklist=>1, whitelist=>0 ) ) {
				foreach my $Interface ( $Host->Interfaces() ) {
					if ( $Interface->mac() ) {
						my $mac = $Interface->mac();
						$mac =~ s/:/\-/g;
						`shorewall drop ~$mac`;
						$log->debug("Dropping !~$mac") if $config{debug};
					} elsif ( $Interface->ip() ) {
						`shorewall drop $$Interface{ip}`;
						$log->debug("Dropping $$$Interface{ip}") if $config{debug};
					} # end if
				} # end foreach mac
			} # end foreach Host
		} # end if
		$log->debug("Done updating shorewall.") if $config{debug};
	} # end if do update

	while ($sock->recv($buf, $MAXLEN)) {
		next if !$buf;
		#my ($port, $ipaddr) = IO::Socket::sockaddr_in($sock->peername);
		#my $hn = gethostbyaddr($ipaddr, Socket::AF_INET);
		#$log->debug($buf) if $config{debug};
		# Without the multiline flag, will do one line at a time, nice.
		my ( $thing1, $line ) = $buf =~ /<(\d+)>(.*)/;
		if ( ! $line ) {
			$log->debug("no line for buf($buf)");
			next;
		} 
		my $changed = 0;
		foreach my $re ( @re ) {
			#$log->debug("Checking Line: $re") if $config{debug};

			if ( $line =~ /$re/ ) {
				my ($when, $source) = ( $1, $+{IP} );
				$log->debug("match for source: $source\nline:$line\nre:$re") if $config{debug};
				my ( $ip, $hostname );
				if ( $source =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
	# Is an IP
					$log->debug("$source is an ip") if $config{debug};
					$ip = $source;
        } elsif ( $source =~ /^(?:[a-fA-F0-9]{1,4}:){7}[a-fA-F0-9]{1,4}$/ ) {
	# Is an IP
					$log->debug("$source is an ipv6") if $config{debug};
					$ip = $source;
				} elsif ($hostname_lookups{$source}) {
					$hostname = $source;
					$ip = $hostname_lookups{$source};
				} else {
	# is a hostname
					$hostname = $source;
					$ip = gethostbyname($source);
					if ( defined $ip ) {
						$ip = Socket::inet_ntoa($ip);
						$hostname_lookups{$source} = $ip;
						$log->debug("Got $ip for $source") if $config{debug};
					} # end if
				} # end if

				if ( ! $ip ) {
					$log->debug("No ip for $source") if $config{debug};
					next;
				} # end if

				if ( $ip eq '127.0.0.1' ) {
					$log->debug('No more testing for localhost');
					next;
				} else {
					$log->debug("IP is $ip");
				} # end if

				if ( $whitelist{$ip} ) {
					$log->debug("$ip is whitelisted") if $config{debug};
					last;
				} # end if

				if ( ! $host_counts{$ip} ) {
					$log->debug("$ip not in host_counts, adding it");
					my $Host;
          # May return a subnet
					my $HI = openprint::Host_Interface->find_one('ip >>='=>$ip);
					if ( !$HI ) {
						$HI = new openprint::Host_Interface();
						$Host = new openprint::Host();
						$Host->save({hostname=>$hostname});
						$HI->save({host_id=>$$Host{id}, ip=>$ip});
					} else {
            if ( $HI->is_subnet() ) {
              $Host = $HI->Host()->copy();
              $Host->save({hostname=>$hostname, description=>$Host->description().' was ' . $Host->hostname()});
              my $HI = $HI->copy();
              $HI->save({host_id=>$$Host{id}, ip=>$ip});
            } else {
              $Host = $HI->Host();
            }
					} # end if      
					$host_counts{$ip} = $Host;
				} # end if

				my $updated_on_dt = $parser->parse_datetime($host_counts{$ip}{updated_on});

				# Instead of parsing when, we just use the current time
				my $now_dt = DateTime->now( time_zone=>$config{Timezone} );

        my $Host = $host_counts{$ip};
				if ( $$Host{updated_on} and ! $$Host{updated_on_seconds} ) {
					$$Host{updated_on_seconds} = $updated_on_dt->epoch();
					$log->debug("Converting  $$Host{updated_on} to $$Host{updated_on_seconds} seconds") if $config{debug};
				}
	#$log->warn("Last: $host_counts{$ip}{updated_on} => $last_seen, $when => $occurrence") if $host_counts{$ip};
				#if ( DateTime->compare( $updated_on_dt, $now_dt ) <= 0 ) {
					$$Host{count} += 1;
$log->debug("count for $ip is $$Host{count}");
					$$Host{update} = 1;
          $$Host{matches} = [] if ! $$Host{matches};
          push @{$$Host{matches}}, "$line matched by $re";
					$changed = $ip;
				#} else {
					#$log->debug( "Not counting because too old " . $host_counts{$ip}{updated_on} . " >= $when " ) if $config{debug};
					#$log->debug( "Not counting because too old " . $updated_on_dt->epoch() . " >= " . $now_dt->epoch() ) if $config{debug};
				#} # end if
				last; # re
			} # end if line matches re
		} # end foreach re

		if ( $changed ) {
			my $ip = $changed;
			$log->debug('# of entries in host_counts: '. keys %host_counts) if $config{debug};
      my $Host = $host_counts{$ip};
      my $count = $$Host{count};
      $Host->load(); # refresh from db
      if ( $$Host{whitelist} ) {
        delete $host_counts{$ip};
        next;
      }
      $$Host{count} = $count;

      if ( ! defined $$Host{count} ) {
        $$Host{count} = 0;
      }
      if ( ! $$Host{blacklist} ) {
        $$Host{blacklist} = 1 if $$Host{count} > 20;
        if ( $dbh and $dbh->ping() ) {
          $_ = $Host->save();
          $log->error($_) if $_;
          $$Host{updated_on_seconds} = time;
        } # end if dbh is alive
        #$log->debug( "$ip $host_counts{$ip}{ip} $host_counts{$ip}{count}" ) if $config{debug};
      } 
      if ( $$Host{count} > 20 ) {
        $log->debug("Dropping $ip because $$Host{count} > 20");
        `shorewall drop $ip`;
        (new openprint::Log())->save({
            Object=>$Host,
            action=>'Blacklist',
            note=>join('<br/>', @{$$Host{matches}}),
          });
        $$Host{matches} = [];
      } # end if wasn't blacklisted, but now is
			$changed = 0;
		} elsif ( $config{debug} ) {
			$log->debug("No match or changes for $line") if $config{debug};
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
