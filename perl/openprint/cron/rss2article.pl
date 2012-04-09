#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use 5.10.0;
use utf8;

# INCLUDES
use strict;
use XML::RSS;
use LWP::Simple;

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
use openprint ();

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

use File::Basename qw(basename);
use Getopt::Long;
use Mail::Sendmail;
use MIME::QuotedPrint;
use MIME::Base64 qw(encode_base64);
use Time::HiRes qw(usleep);
use Encode;

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

$log = new logger('level'=>'debug');
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
configuration::init_cache( $log, $dbh, \%CFG::Config );

# create new instance of XML::RSS
my $rss = new XML::RSS;

foreach my $RSS_Feed ( split(',', ( $CFG::Config{'RSS_Feeds'} ? $CFG::Config{'RSS_Feeds'} : $config{'RSS_Feeds'} ) ) ) {
	my $content;
	my $file;
	my $arg = $RSS_Feed;
# argument is a URL
	if ($arg=~ /http:/i) {
		$content = get($arg);
		die "Could not retrieve $arg" unless $content;
# parse the RSS content
		$rss->parse($content);

# argument is a file
	} else {
		$file = $arg;
		die "File \"$file\" does't exist.\n" unless -e $file;
# parse the RSS file
		$rss->parsefile($file);
	} # end if

    # print the channel items
    foreach my $item (@{$rss->{'items'}}) {
		next unless defined($item->{'title'}) && defined($item->{'link'});
		print "<li><a href=\"$item->{'link'}\">$item->{'title'}</a><BR>\n";
		my $Article = openprint::Article->find_one('title'=>$item->{'title'});
		if ( ! $Article ) {
			$Article = new openprint::Article();
			$Article->save({
				'title'	=>	$item->{'title'},
				'body'	=>	$item->{'description'},
				'source'	=>	$item->{'link'},
			});
		} # end if
    } # en dforeach
} # end foreach RSS_Feed


# SUBROUTINES
sub print_html {
    my $rss = shift;
    print <<HTML;
<table bgcolor="#000000" border="0" width="200"><tr><td>
<TABLE CELLSPACING="1" CELLPADDING="4" BGCOLOR="#FFFFFF" BORDER=0 width="100%">
  <tr>
  <td valign="middle" align="center" bgcolor="#EEEEEE"><font color="#000000" face="Arial,Helvetica"><B><a href="$rss->{'channel'}->{'link'}">$rss->{'channel'}->{'title'}</a></B></font></td></tr>
<tr><td>
HTML

    # print channel image
    if ($rss->{'image'}->{'link'}) {
		print <<HTML;
		<center>
			<p><a href="$rss->{'image'}->{'link'}"><img src="$rss->{'image'}->{'url'}" alt="$rss->{'image'}->{'title'}"
HTML
		print " width=\"$rss->{'image'}->{'width'}\"" if $rss->{'image'}->{'width'};
		print " height=\"$rss->{'image'}->{'height'}\"" if $rss->{'image'}->{'height'};
		print "></a></center><p>\n";
    } # end if


    # if there's a textinput element
    if ($rss->{'textinput'}->{'title'}) {
		print <<HTML;
	<form method="get" action="$rss->{'textinput'}->{'link'}">
	$rss->{'textinput'}->{'description'}<BR> 
	<input type="text" name="$rss->{'textinput'}->{'name'}"><BR>
	<input type="submit" value="$rss->{'textinput'}->{'title'}">
	</form>
HTML
    } # en dif

    # if there's a copyright element
    if ($rss->{'channel'}->{'copyright'}) {
		print <<HTML;
		<p><sub>$rss->{'channel'}->{'copyright'}</sub></p>
HTML
	} # end if

	print <<HTML;
	</td
		</TR>
		</TABLE>
		</td></tr></table>
HTML
} # END sub print_html

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
1;
__END__
