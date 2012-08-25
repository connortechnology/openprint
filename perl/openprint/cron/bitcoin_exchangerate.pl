#!/usr/bin/perl 
use lib '/var/www/testing/perl';
use 5.10.0;
use utf8;

# INCLUDES
use strict;
use JSON ();
use LWP::UserAgent ();
use HTTP::Request ();

use Data::Dumper;
require configuration;
require sql;
require ssi;
require misc;
require openprint::Company;
require openprint::User;
require Email::Valid;
require openprint::Email;
require openprint::User_Notification;
require logger;
require openprint::Article;
require openprint::Feed;
require Date::Parse;
require Date::Format;
use openprint ();

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use File::Basename qw(basename);
use Getopt::Long;
use Mail::Sendmail;
use MIME::QuotedPrint;
use Time::HiRes qw(usleep);
use Encode qw(encode);

my $program = basename($0);

my @args = @ARGV;

my $opts = {};
GetOptions($opts, 'help', 'log_file=s', 'log_level=s',
	'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s',
 );

if ($opts->{help}) {
	usage();
	exit 0;
}

$log = new logger( {'level'=>'debug'});
configuration::from_file('/etc/bitcoin_exchangerate.conf');
configuration::merge( $opts );
$log->level($config{'log_level'}) if $config{'log_level'};

# Declare variables
foreach my $param ( 'db_name','db_user','db_pass' ) {
	if ( ! $config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param
$openprint::dbh = sql::open_sql( $log, 
	'host'		=> $config{'db_host'},
	'database'	=> $config{'db_name'},
	'driver'	=> 'Pg',
	'login'		=> $config{'db_user'},
	'password'	=> $config{'db_pass'},
);
die 'Error opening db' if ! $dbh;
configuration::init( $log, $dbh, \%CFG::Config );
configuration::from_file('/etc/bitcoin_exchangerate.conf');
configuration::merge( $opts );

my $url = 'http://bitcoincharts.com/t/weighted_prices.json';

my $ua = LWP::UserAgent->new;
$ua->agent("MyApp/0.1 ");
# Create a request
my $req = HTTP::Request->new(GET => $url );
# Pass request to the user agent and get a response back
my $res = $ua->request($req);
# Check the outcome of the response
if ($res->is_success) {
	$log->debug("Content: " . $res->content );
	my $content = $res->content;
	my $rates = JSON::decode_json( $content );
	print " CAD Rate: $$rates{CAD}{30d}\n";
} else {
	$log->error("Bad status" . $res->status_line );
	$variable{'information'} .= 'Unable to grab content from source.: ' . $res->status_line . '<br/>';
} # end if

$dbh->disconnect();

1;
__END__
