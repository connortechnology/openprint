#!/usr/bin/perl -wT
use utf8;
use lib '/etc/apache2/lib/perl';
use strict;

require configuration;
require sql;
require openprint::Host;
require logger;

use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
#*config = \%openprint::config;
$log = logger->new();
$log->{level} = 'warn';

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
} else {
	$log->debug("Successfully read cfg");
	foreach my $k ( keys %CFG::Config ) {
		$log->debug("$k => $CFG::Config{$k}");
	} # end foreach
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
$CFG::Config{'sleep'} = 1.0 if ! $CFG::Config{'sleep'};

if ( $CFG::Config{'pid_file'} ) {
	my $pidh;
	if (open($pidh, '> '.$CFG::Config{'pid_file'} ) ) {
		print $pidh $$."\n"; 
		close($pidh);
	} else {
		die "Unable to open pid file";
	} # end if
} # end if

while(1) {
	if ( ! $dbh ) {
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

	foreach my $Host ( openprint::Host->find('monitored'=>1) ) {
		my $ping = $Host->ping();
		if ( $Host->online() != $ping ) {
			$Host->save({'online'=>$ping});
		} # end if
	} # end foreach $Host
	sleep $CFG::Config{'sleep'};
} # end while
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
