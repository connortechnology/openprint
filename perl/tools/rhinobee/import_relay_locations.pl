#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use utf8;
use strict;
use Encode;

require sql;
require logger;
require openprint::Object;
require openprint::Host;
require openprint::Location;
require Text::CSV;
require Geo::Coordinates::Transform;

use openprint ();
use vars qw( $log );
*log = \$openprint::log;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$openprint::config{db_name} = 'rhinobee';
my $dbh = $openprint::dbh = sql::open_sql( $log, (database=>'rhinobee', driver=>'Pg',login=>'rhinobee', password=>'rhinobee', host=>'localhost') );

my $file ='allrelays_locations_2023.csv';
my $csv = Text::CSV->new({ sep_char => ',' });
my $geo = new Geo::Coordinates::Transform();
my $california = openprint::Location->find_one(name=>'California');

open my $fh, $file or die "Unable to open file $file $!";

while (my $line = <$fh>) {
  chomp $line;
  $line =~ s/[^\x{0000}-\x{007F}]+/ /g;
  #$line = Encode::encode_utf8($line);
  if ($csv->parse($line)) {
    my ( undef, undef, $rbid, $relay, $lat, $long, $grade, $cabinet, $consumption) = $csv->fields();

    $relay =~ s/,//g;
    if (!$relay) {
      print "No relay for $line?";
      next;
    }
    my $host = openprint::Host->find_one(name=>$relay);

    if (!$host) {
      $relay =~ s/ Relay//;
      $host = openprint::Host->find_one(name=>$relay);
      $host = openprint::Host->find_one(abbr_name=>$relay) if !$host;

      if (!$host and confirm("Host not found for $relay add?")) {
        $host = new openprint::Host();
        $host->save({name=>$relay});
      }
    }
    if ($host) {

      my $Info = $host->Info('grade');
      if (!$Info) {
        $Info = new openprint::Host_Info();
        $Info->save({host_id=>$host->id(), name=>'grade', value=>$grade});
      } elsif ($Info->value() ne $grade) {
        if (confirm("Update grade from $$Info{value} to $grade", 'Y')) {
          $Info->save({value=>$grade});
        }
      }
      my $Info = $host->Info('cabinet');
      if (!$Info) {
        $Info = new openprint::Host_Info();
        $Info->save({host_id=>$host->id(), name=>'cabinet', value=>$cabinet});
      } elsif ($Info->value() ne $cabinet) {
        if (confirm("Update cabinet from $$Info{value} to $cabinet", 'Y')) {
          $Info->save({value=>$cabinet});
        }
      }

      my $location = $host->Location();
      $lat =~ s/[^0-9\.]/ /g;
      $long =~ s/[^0-9\.]/ /g;
      print "Lat $lat long $long\n";
      if ($lat and $long) {
        my $out_ref = $geo->cnv_to_dd([$lat, $long]);

        if (1*$$out_ref[0] and 1*$$out_ref[1] and !$location->latitude() or $location->latitude() != $$out_ref[0] or $location->longitude() != $$out_ref[1]) {
          if (confirm("Location doesn't match for relay $relay $$location{latitude} != $$out_ref[0] $$location{longitude} != $$out_ref[1], update? Y|n", 'Y')) {
            if (!$location->id()) {
              $location->type('relay');
              $location->name($host->name());
              $location->parent_id($california->id());
            }
            $location->latitude($$out_ref[0]);
            $location->longitude($$out_ref[1]);
            $location->save();
            if (!$host->location_id()) {
              $host->save({location_id=>$location->id()});
            }
          }
        } # end if change
      } # end if lat and long
    }

  } else {
    print "Failed parsing $line\n";
  }
}
$dbh->disconnect();

sub confirm {
my $prompt = shift || 'confirm?';
my $default = shift || 'Y';

my $yesno = 0;
print($prompt . ($default eq 'Y'?'Y':'y').'/'.($default eq 'N' ? 'N' : 'n'). '/q: ');
my $char = <>;
chomp($char);
exit(0) if $char eq 'q';
$char = $default if !$char;
$yesno = ( $char =~ /[yY]/ );
return $yesno;
}

1;
__END__
