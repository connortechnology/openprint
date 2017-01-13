#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';

use sql;
use sets;

use strict;
use Date::Parse;
use Date::Calc;
use Socket;
require openprint::Host;

require logger;

use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
#*config = \%openprint::config;

use Getopt::Long;
use File::Basename qw(basename);

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','blacklist=s', 'debug=s', 'file=s','log_level=s' );

if ($opts->{help}) {
    usage();
    exit 0;
}

unless ($opts->{db_name}) {
    print STDERR "$program: missing required --db_name parameter\n";
    exit 1;
}
unless ($opts->{db_user}) {
    print STDERR "$program: missing required --db_user parameter\n";
    exit 1;
}
unless ($opts->{db_pass}) {
    print STDERR "$program: missing required --db_pass parameter\n";
    exit 1;
}
unless ($opts->{file}) {
    print STDERR "$program: missing required --file parameter\n";
    exit 1;
}

$dbh = sql::open_sql( $log,
    'host'      => $opts->{'db_host'},
    'database'  => $opts->{'db_name'},
    'driver'    => 'Pg',
    'login'     => $opts->{'db_user'},
    'password'  => $opts->{'db_pass'},
);
die 'Error opening db' if ! $dbh;

$log = logger->new( {
( $$opts{'log_file'} ? ( 'file'=>$$opts{'log_file'} ) : () ),
( $$opts{'log_level'} ? ( 'level'=>$$opts{'log_level'} ) : ( 'level'=>'warn' ) ),
} );

my @log_files = ref $opts->{file} eq 'ARRAY' ? @{$opts->{file}} : ( $opts->{file} );

my @re = (
'^\[(\w{3} \w{3} [ :0-9]{16})\] \[[a-z]+\] \[client ([\.0-9]+)\] File does not exist:',
);

my $ac = sql::start_transaction( $dbh );
#$dbh->do( 'LOCK TABLE Hosts IN ACCESS EXCLUSIVE MODE' ) or $log->error( DBI->errstr );
my %host_counts;
my @whitelist = sql::execute( undef, undef, 'SELECT ip FROM HOSTS where whitelist=?', 1 );

foreach my $log_file ( @log_files ) {
	$log->debug("Trying $log_file");
	if ( open( FH, "<$log_file" ) ) {
		foreach my $line (<FH>) {
			foreach my $re ( @re ) {
				$log->debug( "Trying $re against $line\n" );
				if ( $line =~ /$re/ ) {
					my ($when, $source ) = ( $1, $2 );
					$log->debug( "matched $re against $line for $source\n" );
					my ( $ip, $hostname );
					if ( $source =~ /^\d+\.\d+\.\d+\.\d+$/ ) {
						# Is an IP
						$log->debug( "$source is an ip\n" );;
						$ip = $source;
					} else {
						# is a hostname
						$hostname = $source;
						$ip = gethostbyname($source);
						if ( defined $ip ) {
							$ip = Socket::inet_ntoa($ip);
							$log->debug( "Got $ip for $source\n" );
						} # end if
					} # end if
					if ( $ip and @whitelist and sets::isin( $ip, \@whitelist ) ) {
						$log->debug( "$ip is whitelisted\n" );
					} # end if
					if ( ! $ip ) {
						$log->debug( "No ip for $source\n" );
					} else {
						if ( ! $host_counts{$ip} ) {
							my $Host = openprint::Host->find_one('ip'=>$ip);
							if ( $Host ) {
								$host_counts{$Host->ip()} = $Host;
							} else {
								$host_counts{$ip} = new openprint::Host();
								$host_counts{$ip}->ip( $ip );
								$host_counts{$ip}->hostname( $hostname );
							} # end if
						} # end if
						my $last_seen = Date::Parse::str2time( $host_counts{$ip}{updated_on} ) if $host_counts{$ip};
						my $occurrence = Date::Parse::str2time( $when );
#$log->warn("Last: $host_counts{$ip}{updated_on} => $last_seen, $when => $occurrence") if $host_counts{$ip};
						if ( (!$last_seen) or ($last_seen < $occurrence) ) {
							$host_counts{$ip}{'count'} += 1;
							$host_counts{$ip}{'update'} = 1;
						} else {
						print "Not counting because too old " . $host_counts{$ip}{updated_on} . " >= $when" if $opts->{debug};	
						} # end if
					} # end if
					last;
				} # end if line matches re
			} # end foreach re
		} # end if
		close( FH );
	} else {
		$log->error("Unable to open $log_file $!");
	} # end if
} # end foreach

foreach my $ip ( sort keys %host_counts ) {
	next if ! $host_counts{$ip}{'update'};
	if ( $host_counts{$ip}{'count'} > 5 ) { 
		$host_counts{$ip}{'blacklist'}=1;
	} # end if
	if ( ! $host_counts{$ip}->id() ) {
		next if openprint::Host->find_one('ip'=>$ip);
	} # end if
	$_ = $host_counts{$ip}->save();
	if ( $_ ) {
		print $_ . "\n";
	} # end if
	print "$ip $host_counts{$ip}{ip} $host_counts{$ip}{count}\n" if $opts->{debug};
} # end foreach ip
sql::end_transaction( $dbh, $ac );

if ( $opts->{'blacklist'} ) {
	if ( ! open( FH, '>'.$opts->{'blacklist'} ) ) {
		die 'Unable to open blacklist: ' . $opts->{'blacklist'} . "\n";
	} else {
		foreach my $Host ( openprint::Host->find('blacklist'=>1,'order'=>'ip') ) {
			if ( my $macs = $Host->mac() ) {
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
} # end if

sub usage {
	print <<EOH;

usage: logcheck [--help] 

The purpose of this script is to monitor the AuthLog looking for attacks.

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

1;
__END__
