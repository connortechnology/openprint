#!/usr/bin/perl
use lib "/etc/apache2/lib/perl";
use strict;
use utf8;

use File::Basename qw(basename);
use Getopt::Long;

require sql;
require logger;
require misc;
require ssi;
require openprint::Object;
require openprint::EmailCampaign;
require configuration;

use openprint;
use vars qw( %variable $log $dbh %config %session );
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;

my $program = basename($0);

my @args = @ARGV;

my $opts = {};
GetOptions($opts, 'help', 'log_file=s', 'log_level=s',
    'db_port=s', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
	'config=s', 'campaign_id=s',
);

if ($opts->{help}) {
    usage();
    exit 0;
}

$$opts{config} = '/etc/openprint/emailer-scheduler.conf' if ! $$opts{config};

$log = new logger( {level=>'warn'});
configuration::init();
configuration::from_file( $$opts{config} );
configuration::merge( $opts );

# required params
foreach my $param ( 'db_name','db_user','db_pass' ) {
	die "$program: missing required --$param parameter" if ! $config{$param};
} # end foreach required-param


$log->info("Opening SQL connection");
$dbh = sql::open_sql( $log, 
	port			=> $config{db_port},
	host			=> $config{db_host},
	database	=> $config{db_name},
	driver		=> 'Pg',
	login			=> $config{db_user},
	password	=> $config{db_pass},
);
die 'Error opening db' if ! $dbh;
configuration::from_db( );
configuration::from_file( $$opts{config} );
configuration::merge( $opts );

$session{company_id} = $config{owner_id};
$ENV{DOCUMENT_ROOT} = $config{DOCUMENT_ROOT};

openprint::session_init();

# The first query to execute grabs the ids of all of the email campaigns
# that are currently set to run
openprint::EmailCampaign->lock();
my @campaign_ids = openprint::EmailCampaign->find( $$opts{campaign_id} ? ( id=>$$opts{campaign_id} ) : (active => 'Y', 'nextrun <' => 'NOW()', 'custom'=>['(timeofday IS NULL) OR (timeofday <= CURRENT_TIME)'] ) );

$log->info("There are ".@campaign_ids." active campaigns\n");

# For each campaign, we need to get the associated query and interval of
# between the last login time and now (which will be our threshold of concern)
foreach my $Campaign (@campaign_ids) {
	
	$Campaign->send();
	#print "Done campaign " . $Campaign->name() . "\n";
} # foreach campaign_id
openprint::EmailCampaign->unlock();

$dbh->disconnect();

1;
__END__
