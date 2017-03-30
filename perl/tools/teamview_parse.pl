#!/usr/bin/perl
use lib '/var/www/testing/perl/';
use strict;
use warnings;

use Getopt::Long;
use File::Basename qw(basename);
require configuration;
require sql;
require openprint::Host;
require openprint::Host_Info;
require logger;
require openprint::Email;
require openprint::Timetrack;
require openprint::Log;

use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
$log = logger->new( 'debug' );


my $opts = {};
GetOptions( $opts, 'help',
        'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s', 'debug=s', 'config=s', 'filename=s', 'commit=s', 'starting=s',
        );

if ($opts->{help}) {
    usage();
    exit 0;
}

my $program = basename($0);
my %defaults = (
    config  =>  "/etc/openprint/$program.conf",
);
foreach my $default ( keys %defaults ) {
    $$opts{$default} = $defaults{$default} if ! $$opts{$default};
} # end foreach
$log->debug("Init config");
configuration::init( );
configuration::from_file( $$opts{config} );
configuration::merge( $opts );

foreach my $param ( 'db_name','db_user','db_pass' ) {
    if ( ! $openprint::config{$param} ) {
        die "$program: missing required --$param parameter";
    }
} # end foreach required-param

$log->debug("Connecting to db");
$openprint::dbh = sql::open_sql( $log,
        'port'      => $config{'db_port'},
        'host'      => $config{'db_host'},
        'database'  => $config{'db_name'},
        'driver'    => 'Pg',
        'login'     => $config{'db_user'},
        'password'  => $config{'db_pass'},
        );
if ( ! $dbh ) {
    die "Error opening db. $!";
} # end if
$log->debug("Connected to db");


my $filename = '.local/share/teamviewer12/logfiles/Connections.txt';
if ( ! open( FH, '<'.$filename ) ) {
	die "Can't open $filename: $!";
}

configuration::init( );
configuration::from_file( $$opts{config} );
configuration::merge( $opts );
openprint::session_init();

my $Service = openprint::Service->find_one(name=>'Administration & Maintenance');
die "Can't find Administration & Maintenance service." if ! $Service;

if ( $$opts{starting} ) {
  print "Using starting date $$opts{starting}\n";
  $$opts{starting} = Date::Parse::str2time($$opts{starting});
  print "Using starting date $$opts{starting}\n";
}

foreach my $line (<FH>) {
  print "$line\n";

  my ( $starttime, $endtime, $id, $user, $type, $uuid );
  my ( $start_date, $start_time, $end_date, $end_time );
    ( $id, $start_date, $start_time, $end_date, $end_time, $user, $type, $uuid ) = split(/\s+/, $line );
    print "$id, $start_date $start_time, $end_date $end_time, $user, $type, $uuid\n";

    next if ! $id;

    $start_date = join('-', reverse split('-',$start_date));
    $end_date = join('-', reverse split('-',$end_date));

    $starttime = Date::Parse::str2time($start_date .' ' . $start_time);
    $endtime = Date::Parse::str2time($end_date .' ' . $end_time);
    if ( ! ( $starttime and $endtime ) ) {
      $log->warn("Unable to parse start/end time.");
      next;
    }
    if ( $$opts{starting} ) {
      if ( $starttime < $$opts{starting} ) {
        $log->debug("Next because  $starttime < $$opts{starting}");
        next;
      } else {
        $log->debug("Not Next because  $starttime < $$opts{starting}");
      } 
    }

    my $Host_Info = openprint::Host_Info->find_one( name=>'Teamviewer ID', value=>$id );
    if ( $Host_Info ) {
      my $Host = $Host_Info->Host();
      print "Found Host " . $Host->hostname() . " belonging to " . $Host->Owner()->name()."\n";


      my $start_DT = DateTime->from_epoch( epoch=>$starttime, time_zone=>$openprint::TZ );
      my $end_DT = DateTime->from_epoch( epoch=>$endtime, time_zone=>$openprint::TZ );

      my @Employees = openprint::User->find( 'email ilike' => "$user@%" );;
      my $Employee = $Employees[0];

      my $parser = 'DateTime::Format::Pg';
      if ( ! openprint::Timetrack->find( 
            starting	=>	$parser->format_datetime( $start_DT ), 
            ending		=>	$parser->format_datetime( $end_DT ),
            company_id	=>	$Host->owner_id(),
            user_id		=>	$$Employee{id},
            ) ) {
        $log->info("No Timetrack found. Add?");
        $_ = <STDIN>;
        chomp;
        if ( $_ eq 'Y' or $_ eq 'y' ) { 
          my $Timetrack = new openprint::Timetrack();
          $_ = $Timetrack->save({
              starting			=>	$parser->format_datetime( $start_DT ), 
              ending				=>	$parser->format_datetime( $end_DT ),
              company_id		=>	$Host->owner_id(),
              user_id				=>	$$Employee{id},
              service_id			=>	$$Service{id},
              time_associated		=>	1,
              travel_associated	=>	0,
              currency_id			=>	$Host->Owner()->currency_id(),	
              description     =>  'Teamview connection to ' . $Host->hostname(),

              });
          $log->error($_) if $_;
        }
      } # TImetrack not found

    } else {
      $log->error("No host found for id $id");
    }
} # end foreach line
close(FH);

$dbh->disconnect();
exit(0);
sub usage {
  print <<EOH;

usage: teamview_parse.pl [--help] 

The purpose of this script is to parse teamviewer logs

Command-line options:

  --help    Displays this message.

EOH
} # end sub usage

1;
__END__
