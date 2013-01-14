#!/usr/bin/perl 
use lib '/var/www/testing/perl';
use strict;
use warnings;
use File::Basename qw(basename);

require configuration;
require sets;
require sql;
require logger;
require openprint::Asset;
use Getopt::Long;

use openprint ();
use vars qw($log $dbh %config %session);
*dbh = \$openprint::dbh;
*log = \$openprint::log;
*config = \%openprint::config;
*session = \%openprint::session;

my $program = 'video_assets.pl';
$log = logger->new('warn');
my $opts = {};
GetOptions($opts, 'help', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','debug=s');

if ($opts->{help}) {
    usage();
    exit 0;
}
if ( $opts->{debug}) {
    $$log{level} = $opts->{debug};
}

unless ($opts->{db_name}) {
    print STDERR "$program: missing required --db_name parameter\n";
    exit 1;
}
$opts->{db_user} = $opts->{db_name} if ! $opts->{db_user};
$opts->{db_pass} = $opts->{db_name} if ! $opts->{db_pass};

$dbh = sql::open_sql( $log,
        'host'      => $opts->{db_host},
        'database'  => $opts->{db_name},
        'driver'    => 'Pg',
        'login'     => $opts->{db_user},
        'password'  => $opts->{db_pass},
        );

die 'Error opening db' if ! $dbh;
configuration::init();

foreach my $Asset ( openprint::Asset->find( ) ) {
	next if ! $Asset->is_video();

	foreach my $type ( 'mp4','ogg','webm' ) {
		my $path = $Asset->video_path($type);

		# Next if already generating
		next if -e $path.'.part';
		# If video exists, will not generate
		$Asset->generate_video($type);
		if ( ! -e $path ) {
			$log->error("Was unsuccessful in generating video at $path");
		} # en dif
	} # end foreach $type
} # end foreach Asset

$dbh->disconnect();


sub usage {
	print <<EOH;

usage: $program [--help] [--db_name \$db_name] [--db_host \$db_host] [--db_user \$db_user] [--db_pass \$db_pass] filename

The purpose of this script is to convert uploaded videos to their various 
web formats.

Command-line options:

	--help		Displays this message.

	--db_host	The hostname of the machine on which the database resides.

	--db_name	The name of the database.
	
	--db_user	The name of the user to use when connecting to the database.

	--db_pass	The password to use when connecting to the database.

    --output    File to store the session count in.

EOH
}
1;
__END__
