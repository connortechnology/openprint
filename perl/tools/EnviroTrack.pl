#!/usr/bin/perl
use lib './EnviroTrack';
use strict;
use warnings;

require EnviroTrack;
require EnviroTrack::sql;
require EnviroTrack::logger;
require EnviroTrack::configuration;

use vars qw( $log $dbh %config);
*log = \$EnviroTrack::log;
*dbh = \$EnviroTrack::dbh;
*config = \%EnviroTrack::config;

$log = EnviroTrack::logger->new();
$log->{level} = 'debug';

use Getopt::Long;
use File::Basename qw(basename);

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help',
		'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s', 'debug=s', 'config=s',
		);

if ($opts->{help}) {
    usage();
    exit 0;
}

my %defaults = (
    config  =>  '/etc/EnviroTrack/EnviroTrack.conf',
	sleep	=>	10,
);
foreach my $default ( keys %defaults ) {
    $$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach

if ( $opts->{debug}) {
    $$log{level} = $opts->{debug};
}

EnviroTrack::configuration::init( );
EnviroTrack::configuration::from_file( $$opts{config} );
EnviroTrack::configuration::merge( $opts );

unless ($config{db_name}) {
    print STDERR "$program: missing required --db_name parameter\n";
    exit 1;
}

$dbh = sql::open_sql( $log,
        host      => $config{db_host},
        database  => $config{db_name},
        driver    => $config{db_type},
        login     => $config{db_user},
        password  => $config{db_pass},
        );

die 'Error opening db' if ! $dbh;
EnviroTrack::configuration::init( );
EnviroTrack::configuration::from_file( $$opts{config} );
EnviroTrack::configuration::merge( $opts );

require EnviroTrack::Sensor;
require EnviroTrack::Sensor::LM;

while(1) {

	if ( ! $dbh->ping() ) {
		$dbh = sql::open_sql( $log,
				host      => $config{db_host},
				database  => $config{db_name},
				driver    => $config{db_type},
				login     => $config{db_user},
				password  => $config{db_pass},
				);

		if ( ! $dbh ) {
			$log->error( 'Error opening db' );
			sleep(1);
		}
		
		EnviroTrack::configuration::init( );
		EnviroTrack::configuration::from_file( $$opts{config} );
		EnviroTrack::configuration::merge( $opts );
	}
 
	foreach my $Sensor ( new EnviroTrack::Sensor::LM(), EnviroTrack::Sensor->find() ) {
		foreach my $Input ( $Sensor->Inputs() ) {
			$log->debug("Got input $$Input{name}");
			$Input->take_reading();
		} # end foreach Sensor
	} # end foreach Monitor
	$log->debug("Sleeping for $config{sleep} seconds");
	sleep( $config{sleep} );
} # end big while looput
1;
__END__
