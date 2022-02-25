#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;
use warnings;
use File::Basename qw(basename);

require configuration;
require sets;
require sql;
require logger;
require misc;
use Getopt::Long;
require Date::Calc;
require Text::CSV_XS;

use openprint ();
use vars qw($log $dbh %config %session);
*dbh = \$openprint::dbh;
*log = \$openprint::log;
*config = \%openprint::config;
*session = \%openprint::session;

my $program = 'import_currency_conversions.pl';
$log = logger->new('debug');
my $opts = {};
GetOptions($opts, 'help', 'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','debug=s','file=s');

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
        host      => $opts->{db_host},
        database  => $opts->{db_name},
        driver    => 'Pg',
        login     => $opts->{db_user},
        password  => $opts->{db_pass},
        );

die 'Error opening db' if ! $dbh;
configuration::init();
configuration::merge($opts);

my $from_id=2;
my $to_id=1;

my $csv = Text::CSV_XS->new();
open ( FH, $$opts{file} ) or die "Can't open $$opts{file} : $!";
while ( <FH> ) {
  my $status = $csv->parse($_);
  my ($period, $usd, $rate) = misc::trim($csv->fields());
  next if $period eq 'date';
  my ($year, $month, $day) = split('-', $period);
  my $period_start = sprintf('%.4d-%.2d-%.2d 12:00:00', $year, $month, $day);
  my $period_end = sprintf('%.4d-%.2d-%.2d 11:59:59', Date::Calc::Add_Delta_Days($year, $month, $day, 1));

  my ( $id, $oldrate ) = sql::execute(undef,undef,'SELECT id, rate FROM currency_conversions WHERE from_id=? AND to_id=? AND period_start=? AND period_end=?', $from_id, $to_id, $period_start, $period_end);
  if ( !$id ) {
    sql::insert(undef, undef, 'currency_conversions',(
        from_id=>$from_id,
        to_id=>$to_id,
        period_start=>$period_start,
        period_end=>$period_end,
        rate=>$rate)
    );
  } else {
    print "Conversion found for $period_start to $period_end, update?";
    my $input = <STDIN>;
    last if $input eq 'q';
  }
} # end while
close(FH);

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

    --AssetPath    File to store the session count in.
	
	--add		File to import

EOH
}
1;
__END__
