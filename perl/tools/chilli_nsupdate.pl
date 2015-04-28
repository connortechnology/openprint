#!/usr/bin/perl
use strict;
#use warnings;
use lib '/var/www/testing/perl';

use Getopt::Long qw(GetOptions);
use File::Basename qw(basename);
require openprint;
require logger;
require sql;
require openprint::Host;

use vars qw( $log $dbh %config);
*dbh = \$openprint::dbh;
*config = \%openprint::config;

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help', 
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','log_level=s',
 );

*log = \$openprint::log;
$log = logger->new('debug');
# Get our configuration information
if (my $err = ReadCfg('/etc/chilli_nsupdate.conf')) {
    die $err;
} # end if

foreach my $param ( 'db_name','db_user','db_pass' ) {
	$CFG::Config{$param} = $$opts{$param} if $$opts{$param};
	if ( ! $CFG::Config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param

foreach my $param ( 'db_host', 'log_file', 'log_level' ) {
	$CFG::Config{$param} = $$opts{$param} if $$opts{$param};
} # end foreach non-required param

$CFG::Config{'log_level'} = 'debug' if ! $CFG::Config{'log_level'};
$log = logger->new( {'file'=>$CFG::Config{'log_file'}, 'level'=>$CFG::Config{'log_level'}} );

if ($CFG::Config{help}) {
    usage();
    exit 0;
}

if ( 1 ) {
if ( $CFG::Config{'log_level'} eq 'debug' ) {
foreach my $k ( keys %ENV ) {
$log->debug("Environment: $k => $ENV{$k}");
}
}
}

if ( $ENV{'CALLING_STATION_ID'} ) {
	if ( $CFG::Config{'db_name'} ) {
		$dbh = sql::open_sql( $log,
				'host'      => $CFG::Config{'db_host'},
				'database'  => $CFG::Config{'db_name'},
				'driver'    => 'Pg',
				'login'     => $CFG::Config{'db_user'},
				'password'  => $CFG::Config{'db_pass'},
				);
		die 'Error opening db' if ! $dbh;
	} else {
		$log->error("Must specify database name in order to look up hosts.\n");
		exit(1);
	} # end if
	my @Interfaces = openprint::Host_Interface->find(mac=>$ENV{'CALLING_STATION_ID'});
	if ( @Interfaces ) {
		foreach my $Interface ( @Interfaces ) {
		if ( $Interface->dhcp() ) {
			if ( $Interface->ip() ne $ENV{'FRAMED_IP_ADDRESS'} ) {
				$_ = $Interface->save({ip=>$ENV{'FRAMED_IP_ADDRESS'}});
				$log->error($_) if $_;

				my $Host = $Interface->Host();
				my $hostname = $Host->hostname();
				if ( $hostname ) {
					if ( $hostname !~ /.internal.point-one.com$/ ) {
						$log->debug("TRanforming $hostname into $hostname.internal.point-one.com");
						$hostname .= '.internal.point-one.com';
					}

				
					if ( open NSUPDATE, "| nsupdate" ) {
						$log->debug("Updating $hostname to $ENV{FRAMED_IP_ADDRESS}");
						print NSUPDATE "server 192.168.2.1\n";
						print NSUPDATE "update delete $hostname. IN A\n";
						print NSUPDATE "update add $hostname. 86400 IN A $ENV{FRAMED_IP_ADDRESS}\n";
						print NSUPDATE "send\n";
						close NSUPDATE;
					} else {
						$log->error("Unable to open NSUPDATE $!");
					} # end if 
				} # end if 
			} else {
				$log->debug("IP unchanged");
			} # end if
		} else {
			$log->debug("IP not changed because dhcp not set for mac $ENV{'CALLING_STATION_ID'} $ENV{'FRAMED_IP_ADDRESS'}");
		} # end if Host->dhcp
		} # end foreach Inteface
	} else {
		$log->debug("Host not found for mac $ENV{'CALLING_STATION_ID'}");

	} # end if Hosts
	$dbh->disconnect() if $dbh;
} else {
	$log->error("No CALLING_STATION_ID");
} # end if
exit(0);

# Read a configuration file
#   The arg can be a relative or full path, or
#   it can be a file located somewhere in @INC.
sub ReadCfg {
    my $file = $_[0];

    our $err;

    {   # Put config data into a separate namespace
        package CFG;
		use vars qw( %Config );

        # Process the contents of the config file
        my $rc = do($file);

        # Check for errors
        if ($@) {
            $::err = "ERROR: Failure compiling '$file' - $@";
        } elsif (! defined($rc)) {
            $::err = "ERROR: Failure reading '$file' - $!";
        } elsif (! $rc) {
            $::err = "ERROR: Failure processing '$file'";
        }
    }

    return ($err);
}

sub usage {
	print <<EOH;

usage: chilli_nsupdate.pl [--help] 

The purpose of this script is to do a dns update when someone connects to the chilli hotspot

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

1;
__END__
