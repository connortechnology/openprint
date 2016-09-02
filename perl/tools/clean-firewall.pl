#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;
use Socket;
require IO::Socket;

require configuration;
require sql;
require logger;
require openprint;
require openprint::Host;
require Date::Calc;

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use File::Basename qw(basename);
use Getopt::Long ();

my $program = basename($0);

my $opts = {};
Getopt::Long::GetOptions($opts, 'help', 'config=s',
	'log_file=s', 'log_level=s',
'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
'debug=s',
);

if ($opts->{help}) {
	usage();
	exit 0;
} # end if

my %defaults = (
	config	=>	'/etc/openprint/syslog.conf',
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

$log->warn("Getting hosts");
foreach my $Host ( openprint::Host->find( blacklist=>1, 'updated_on <=' => sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -30 ) ) ) ) {
	foreach my $HI ( $Host->Interfaces() ) {
	$log->warn("Allowing $$HI{ip}");
	$Host->save({blacklist=>0});
	`shorewall allow $$HI{ip}`;
	}
} # end foreach Host


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

$log->debug('Exiting') if $config{debug};
1;
__END__
