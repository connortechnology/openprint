#!/usr/bin/perl  -w
use lib '/var/www/testing/perl';
use 5.10.0;
use utf8;

# INCLUDES
use strict;
use HTML::TreeBuilder;
use LWP::UserAgent ();
use HTTP::Request ();

use Data::Dumper;
require configuration;
require sql;
require ssi;
require misc;
require openprint::Company;
require openprint::User;
require logger;
require Date::Parse;
require Date::Format;
require openprint;

require openprint::Event;
require openprint::Location;

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use File::Basename qw(basename);
use Getopt::Long;
use Mail::Sendmail;
use MIME::QuotedPrint;
use Time::HiRes qw(usleep);
use Encode qw(decode);

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
# Get our configuration information
configuration::from_file('/etc/openprint/pleasurablethings.conf');
configuration::merge( $opts );
$log->level($config{'log_level'}) if $config{'log_level'};

# Declare variables
foreach my $param ( 'db_name','db_user','db_pass' ) {
	if ( ! $config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param
if ( 1 ) {
$openprint::dbh = sql::open_sql( $log, 
	'host'		=> $config{'db_host'},
	'database'	=> $config{'db_name'},
	'driver'	=> 'Pg',
	'login'		=> $config{'db_user'},
	'password'	=> $config{'db_pass'},
);
die 'Error opening db' if ! $dbh;
}

# Login inputs are member and password, also need VIEWSTATE AND EVENTVALIDATION

my $ua = LWP::UserAgent->new;
$ua->agent("IQ/0.1 ");
# Create a request
my $req = HTTP::Request->new(GET => 'http://oasisaqualounge.com/index.php/products?view=list' );
# Pass request to the user agent and get a response back
my $res = $ua->request($req);
# Check the outcome of the response
if (! $res->is_success) {
    $log->debug("No success.");
	exit(0);
} # end f

my $User = openprint::User->find_one(firstname=>'TONIATOASIS');
if ( ! $User ) {
	my $Company = openprint::Company->find_one(name=>'Oasis Aqualounge');
	if ( ! $Company ) {
		$Company = new openprint::Company();
		$Company->save({name=>'Oasis Aqualounge'});
	} # end if

	$User = new openprint::User();
	$User->save({company_id=>$Company->id(), firstname=>'TONIATOASIS'});
} # end if
	
#$log->debug( "Content: " . $res->content );
my $content = Encode::decode('utf-8',$res->content);

my $tree = HTML::TreeBuilder->new;
$tree->parse_content($content);
$tree->elementify();
foreach my $post ( $tree->look_down('class','ic_listitem') ) {
	$post->dump();
	my $h4 = $post->look_down(_tag => 'h4');
	next if ! $h4;
	my $title = $h4->as_text();
	my $when = $post->look_down(_tag => 'h3')->as_text();
	my $desc_div = $post->look_down( class=>'ic_listitem_description');
	my $desc = $desc_div->as_text() if $desc_div;
	my $posterlink = $desc_div->look_down(_tag=>'a');
	my $posterurl = $posterlink->attr('href') if $posterlink;
	my $Asset = openprint::Asset->find_one();
	$posterlink->dump();
$log->debug("Title: $title, When: $when desc: $desc");
	my ( $month, $day, $year, $hour, $minute, $ampm ) = $when =~ /^\s*(\d+)\.(\d+)\.(\d+)\s+(\d+):(\d+) (\w+)\s*$/m;
	if ( $ampm eq 'pm' ) {
		$hour += 12;
	} # end if
	my ( $ending_year, $ending_month, $ending_day ) = Date::Calc::Add_Delta_Days( $year, $month, $day, 1 );
	my ( $ending_hour, $ending_minute) = ( 3, 0 );
	$log->debug(" Got event $title, $year-$month-$day $hour:$minute $ampm");


	my $Event = openprint::Event->find( name=>$title, starting_on => sprintf('%.4d-%.2d-%.2d %.2d:%.2d:00', $year, $month, $day, $hour, $minute ) );

	next if (
		( $Event->info() eq $desc ) 
	);
	my $Location = openprint::Location->find_one(name=>'Oasis Aqualounge');

	$Event = new openprint::Event();
$Event->save({
name =>  $title,
starting_on	=>	sprintf( '%.4d-%.2d-%.2d %.2d:%.2d:00', $year, $month, $day, $hour, $minute ),
ending_on	=>	sprintf( '%.4d-%.2d-%.2d %.2d:%.2d:00', $ending_year, $ending_month, $ending_day, $ending_hour, $ending_minute ),
info	=>	$desc,
location_id	=>	$Location->id(),
created_by	=>$User->id(),
});

} # end foreach post


1;
__END__
