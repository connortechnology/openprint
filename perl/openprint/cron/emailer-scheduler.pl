#!/usr/bin/perl
use lib "/etc/apache2/lib/perl";
use strict;


require configuration;
require sql;
require logger;
require misc;
require ssi;
require openprint::Object;
require openprint::EmailCampaign;

use MIME::QuotedPrint;
use Mail::Sendmail;
use Encode;
use openprint;
use vars qw( %variable $log $dbh %config %session);
*variable = \%openprint::variable;
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
*session = \%openprint::session;


$log = logger->new();
$log->{level} = "warn";
my %sql_server;

$openprint::Object::no_cache = 1;

# This is a bit of a hack, but it allows us to use similar styled code
# as is found in the apache modules
$ENV{'DOCUMENT_ROOT'} = '/var/www/point-one/www/public_html/';


$log->info("Opening SQL connection");
$dbh = sql::open_sql( $log, 
	'host'		=> $ARGV[0],
	'database'	=> $ARGV[1],
	'driver'	=> 'Pg',
	'login'		=> $ARGV[2],
	'password'	=> $ARGV[3],
);
die 'Error opening db' if ! $dbh;

configuration::init_cache( $log, $dbh, {
		'siteURL' => 'http://www.point-one.com',
		'SecureSiteURL'	=> 'https://www.point-one.com',
		'ExternalSiteURL'	=> 'http://www.point-one.com',
		'ExternalSecureSiteURL'	=> 'https://www.point-one.com',
		'SiteTitle'	=>'PointOne Graphics Inc',
		}
		);
my $site_admin_email = 'iconnor@point-one.com';
$session{'company_id'} = 6;

# The first query to execute grabs the ids of all of the email campaigns
# that are currently set to run
my @campaign_ids = openprint::EmailCampaign::find( 'active' => 'Y', 'misc' => '(nextrun < now()) AND ( timeofday IS NULL or timeofday <= NOW()::time)' );

$log->info("There are ".@campaign_ids." active campaigns\n");

# For each campaign, we need to get the associated query and interval of
# between the last login time and now (which will be our threshold of concern)
foreach my $Campaign (@campaign_ids) {
	$Campaign->send();
	#print "Done campaign " . $Campaign->name() . "\n";
} # foreach campaign_id

$dbh->disconnect();


1;
__END__
