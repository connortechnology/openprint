#!/usr/bin/perl
use utf8;
use lib '/etc/apache2/lib/perl';
use strict;
use LWP;

require configuration;
require sql;
require openprint::Host;
require logger;

use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
#*config = \%openprint::config;
$log = logger->new();
$log->{level} = 'debug';

use Getopt::Long;
use File::Basename qw(basename);

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help', 
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','blacklist=s', 'debug=s',
 );

if ($opts->{help}) {
    usage();
    exit 0;
}

# Get our configuration information
if (my $err = ReadCfg('/etc/iq_monitor.conf')) {
    die $err;
#} else {
	#$log->debug("Successfully read cfg");
	#foreach my $k ( keys %CFG::Config ) {
		#$log->debug("$k => $CFG::Config{$k}");
	#} # end foreach
}

foreach my $param ( 'db_name','db_user','db_pass','from','recipient','smtp-server' ) {
	$CFG::Config{$param} = $$opts{$param} if $$opts{$param};
	if ( ! $CFG::Config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param

foreach my $param ( 'pid_file', 'db_host', 'log_file', 'log_level', 'sleep', 'skin_path','document_root','site_title','site_url' ) {
	$CFG::Config{$param} = $$opts{$param} if $$opts{$param};
} # end foreach non-required param

if ( $CFG::Config{'site_url'} ) {
	$CFG::Config{'siteURL'} = $CFG::Config{'site_url'};
	$CFG::Config{'ExternalSiteURL'} = $CFG::Config{'site_url'};
} # end if
$CFG::Config{'SiteTitle'} = $CFG::Config{'site_title'};
$CFG::Config{'SkinPath'} = $CFG::Config{'skin_path'};

$CFG::Config{'log_level'} = 'debug' if ! $CFG::Config{'log_level'};
$log = logger->new( {'file'=>$CFG::Config{'log_file'}, 'level'=>$CFG::Config{'log_level'}} );

$CFG::Config{'sleep'} = 1.0 if ! $CFG::Config{'sleep'};
#$log->debug("Sleep duration $CFG::Config{sleep}");

#$log->debug("Finalised cfg");
#foreach my $k ( keys %CFG::Config ) {
	#$log->debug("$k => $CFG::Config{$k}");
#} # end foreach

if ( $CFG::Config{'pid_file'} ) {
	#$log->debug("Creating pid file at $CFG::Config{'pid_file'} $$");
	my $pidh;
	if (open($pidh, '> '.$CFG::Config{'pid_file'} ) ) {
		print $pidh $$."\n"; 
		close($pidh);
	} else {
		die 'Unable to open pid file';
	} # end if
} # end if

# udp has less network traffic overhead
my $p = Net::Ping->new('icmp');

while(1) {
	if ( ! ( $dbh and $dbh->ping ) ) {
		$log->debug("Connecting to db");	
		$dbh = sql::open_sql( $log,
				'host'		=> $CFG::Config{'db_host'},
				'database'	=> $CFG::Config{'db_name'},
				'driver'	=> 'Pg',
				'login'		=> $CFG::Config{'db_user'},
				'password'	=> $CFG::Config{'db_pass'},
				);
		if ( ! $dbh ) {
			$log->error( 'Error opening db. Sleeping for 5.' );
			sleep 5;
			next;
		} # end if ! dbh
	} # end if ! dbh

	$log->debug( "Getting hosts" );
	my @Hosts = openprint::Host->find('monitored'=>1);
	$log->debug( 'Monitoring ' . @Hosts . ' hosts.' );
	foreach my $Host ( @Hosts ) {
		$log->debug( $Host->hostname() . ' is ' . ( $Host->online() ? 'online' : 'offline' ) );
		my $ping = $p->ping($Host->ip());
		if ( ! defined $ping ) {
			$log->warn("Problem with ping for " . $Host->hostname() );
			next;
		} # end if
		if ( $Host->online() != $ping ) {
			$Host->save({'online'=>$ping});
			$log->debug( $Host->hostname() . ' is now ' . ( $Host->online() ? 'online' : 'offline' ) );
		} # end if
		if ( $Host->online() ) {
			if ( $Host->type() eq 'AIC500W' ) {
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
					$log->warn("Couldn't get content from " . $Host->hostname().'/cgi/jpg/image.cgi rebooting' . $response->status_line );
				my $headers = $response->headers();
					foreach my $k ( keys %$headers ) {
$log->debug("Header $k => $$headers{$k}");
					}  # end foreach
					$response = $browser->get('http://'.$Host->hostname().'/admin/reboot.cgi?type=0');
					$log->debug($response->is_success);
				} else {
					$log->debug("Got content from host. Size: " . $response->content_type );
				} # end if
			} elsif ( $Host->type() ) {
				$log->warn("unsupported type: " . $Host->type() );
			} # end if
		} # end if online
	} # end foreach $Host
	sleep $CFG::Config{'sleep'};
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


1;
__END__
