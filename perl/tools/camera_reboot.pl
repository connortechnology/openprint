#!/usr/bin/perl -w
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
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','blacklist=s', 'debug=s', 'host_id=s',
 );

if ($opts->{help}) {
    usage();
    exit 0;
}

# Get our configuration information
if (my $err = ReadCfg('/etc/camera_reboot.conf')) {
    die $err;
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


$log->debug("Connecting to db");	
$dbh = sql::open_sql( $log,
		'host'		=> $CFG::Config{'db_host'},
		'database'	=> $CFG::Config{'db_name'},
		'driver'	=> 'Pg',
		'login'		=> $CFG::Config{'db_user'},
		'password'	=> $CFG::Config{'db_pass'},
		);
if ( ! $dbh ) {
	die "Error opening db. $!";
} # end if
configuration::init_cache( $log, $dbh );

# udp has less network traffic overhead
my $p = Net::Ping->new('icmp',10);

my @Hosts = $$opts{host_id} ? openprint::Host->find(id=>$$opts{host_id}) : openprint::Host->find('monitored'=>1,'type in'=>[ 'AIC500', 'AIC500W', 'AIC777W', 'AIC747W','AIC250','AIC250W' ]);
$log->debug( 'Monitoring ' . @Hosts . ' hosts.' );
foreach my $Host ( @Hosts ) {
	if ( ! $Host->ip() ) {
		$log->debug( "Monitored host without ip: " . $Host->to_string() );
		next;
	} # end if
	my @ping = $p->ping($Host->ip());
	my $ping = $ping[0];
#$openprint::log->debug("Ping1: @ping");
	if ( ! @ping ) {
		$log->warn("Problem with ping for " . $Host->hostname() );
		next;
	} # end if

	if ( $Host->online() and $ping ) {
		$Host->reboot();
	} elsif ( $Host->online() ) {
		$log->debug("No ping for $$Host{hostname}");
	} else {
		$log->debug("$$Host{hostname} is offline: ping $ping");
	} # end if online
} # end foreach $Host
$p->close();
$dbh->disconnect() if $dbh;
exit 0;

sub usage {
	print <<EOH;

usage: reboot_camera [--help] 

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
