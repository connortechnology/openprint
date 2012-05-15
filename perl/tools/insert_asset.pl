#!/usr/bin/perl 
use lib '/var/www/testing/perl';
use strict;
use warnings;
use File::Basename qw(basename);

require configuration;
require sets;
require sql;
require logger;
require openprint::User;
require openprint::Asset;
use Getopt::Long;

use openprint ();
use vars qw($log $dbh %config %session);
*dbh = \$openprint::dbh;
*log = \$openprint::log;
*config = \%openprint::config;
*session = \%openprint::session;

my $program = 'insert_asset.pl';
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

my $User = openprint::User->find_one('email like'=>'isaac%');
die "Coulnt find isaac." if ! $User;
$session{'user_id'} = $User->id();
$session{'company_id'} = $User->company_id();
foreach my $file ( @ARGV ) {
	if ( -e $file ) {
		my $Asset = new openprint::Asset();
		$Asset->save({'filename'=> basename($file),
				'created_by'	=>	$session{'user_id'},
				'company_id'	=>	$session{'company_id'},
					});
		my $mv_command = "$file $config{'AssetPath'}/".$Asset->on_disk_filename();
		`mv $mv_command`;
	} # end if
} # end foreach file
print "ARGS @ARGV\n";

sub usage {
	print <<EOH;

usage: $program [--help] [--db_name \$db_name] [--db_host \$db_host] [--db_user \$db_user] [--db_pass \$db_pass] filename

The purpose of this script is to monitor the hotfolders configured for each
press for PPF files and perform conversions for Heidelberg JDF, Merge front 
and backs for presses that require it, and to import the PPF previews and 
other data into the IntelligentQuote system.

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
