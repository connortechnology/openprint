#!/usr/bin/perl 
use lib '/var/www/testing/perl';
use 5.10.0;
use utf8;

# INCLUDES
use strict;
use XML::RSS;
use LWP::Simple;

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
# Get our configuration information
if (my $err = ReadCfg('/etc/rss2article.conf')) {
    die $err;
}
# Declare variables
foreach my $param ( 'db_name','db_user','db_pass' ) {
	$CFG::Config{$param} = $$opts{$param} if $$opts{$param};
	if ( ! $CFG::Config{$param} ) {
		die "$program: missing required --$param parameter";
	}
} # end foreach required-param
$openprint::dbh = sql::open_sql( $log, 
	'host'		=> $CFG::Config{'db_host'},
	'database'	=> $CFG::Config{'db_name'},
	'driver'	=> 'Pg',
	'login'		=> $CFG::Config{'db_user'},
	'password'	=> $CFG::Config{'db_pass'},
);
die 'Error opening db' if ! $dbh;
configuration::init( $log, $dbh, \%CFG::Config );

# create new instance of XML::RSS
my $rss = new XML::RSS;

#my @Feeds = split(',', ( $CFG::Config{'RSS_Feeds'} ? $CFG::Config{'RSS_Feeds'} : $config{'RSS_Feeds'} ) );
#@Feeds = openprint::Feed->find() if ! @Feeds;

foreach my $Feed ( openprint::Feed->find() ) {
	my $content;
	my $file;
	my $arg = $Feed->url();
# argument is a URL
	if ($arg=~ /http:/i) {
		$content = Encode::encode('utf-8',get($arg));
		die "Could not retrieve $arg" unless $content;
# parse the RSS content
		$rss->parse($content);
##$log->debug($content);

# argument is a file
	} else {
		$file = $arg;
		die "File \"$file\" does't exist.\n" unless -e $file;
# parse the RSS file
		$rss->parsefile($file);
	} # end if

#$log->debug("RSS: " . Data::Dumper::Dumper($rss));
#print "RSS: " . Data::Dumper::Dumper($rss) . "\n";
    # print the channel items
    foreach my $item (@{$rss->{'items'}}) {
#$log->debug("Item: " . Data::Dumper::Dumper($item));
#print "Item: " . Data::Dumper::Dumper($item) ."\n";
		next unless defined($item->{'title'}) && defined($item->{'link'});
		my $Article = openprint::Article->find_one('title'=>$item->{'title'});
		if ( ! $Article ) {
			my $User;
			if ( $$item{'dc'} and $$item{dc}{creator} ) {
				$User = openprint::User->find_one('company_id'=>$Feed->company_id(), 'firstname'=>$$item{dc}{creator});
			} # end if
			$item->{'description'} =~ s/\n/ /g;

			# Get rid of the feedburner stuff
			if ( $$item{'http://rssnamespace.org/feedburner/ext/1.0'} and $$item{'http://rssnamespace.org/feedburner/ext/1.0'}{'origLink'} ) {
				$$item{'link'} = $$item{'http://rssnamespace.org/feedburner/ext/1.0'}{'origLink'};
			} # end if

			if ( $Feed->filters() ) {
				foreach my $filter ( split("\n", $Feed->filters() ) ) {
$log->debug("Apply filter $filter");
					eval q`$item->{'description'} =~ `.$filter;
					$log->error( "Eval error, Reason: " . $@ ) if $@;
				} # end foreach filter
$log->debug("after filtering: $$item{'description'}");
			} else {
				$log->warn("No filters ");
				$log->debug("No filters $$Feed{'filters'}");	
			} # end $Feed->filters
			$Article = new openprint::Article();
			$Article->save({
				'title'	=>	$item->{'title'},
				'body'	=>	$item->{'description'},
				'source'	=>	$item->{'link'},
				'published'	=>	$Feed->published(),
				'published_on'	=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S%z', Date::Parse::str2time( $item->{'pubDate'} ) ),
				'created_on'	=>	Date::Format::time2str('%Y-%m-%d %H:%M:%S%z', Date::Parse::str2time( $item->{'pubDate'} ) ),
				'company_id'	=>	$Feed->company_id(),
				'category_id'	=>	$Feed->category_id(),
				( $User ? ( 'created_by'	=> $User->id() ) : () ),
			});
		#$log->debug( $Article->to_string() );
		} else {
$log->debug( "Already have article for $$item{title}" );
		} # end if
    } # en dforeach
} # end foreach Feed

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
