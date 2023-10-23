#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use utf8;
use strict;
use Encode;

require sql;
require logger;
require openprint::Object;
require openprint::Company;
require openprint::Host;

use openprint ();
use vars qw( $log );
*log = \$openprint::log;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
my $dbh1 = sql::open_sql( $log, (database=>'rbd', driver=>'Pg',login=>'webuser', password=>'bigbizDB!007', host=>'10.88.8.3') );
my $dbh2 = $openprint::dbh = sql::open_sql( $log, (database=>'rhinobee', driver=>'Pg',login=>'rhinobee', password=>'rhinobee', host=>'localhost') );

  my $rhinobee = openprint::Company->find_one(name=>'Rhinobee');

my @relays = sql::execute_hash(undef, $dbh1, 'SELECT * FROM relaylayer');
print "We have ".@relays." relays\n";
foreach my $row (@relays) {
  print "$row\n";
  #Column         |            Type             | Collation | Nullable |                    Default
  #rbid               | character varying(255) |           | not null |
  #name               | character varying(255) |           |          |
  #abbr_name          | character varying(255) |           |          |
  #relay_type         | character varying(255) |           |          |
  ##parent_relay       | character varying(255) |           |          |
  #relay_class        | character varying(255) |           |          |
  #battery_box        | character varying(255) |           |          |
  #bb_quantity        | character varying(255) |           |          |
  ##ssid               | character varying(255) |           |          |
  #key                | character varying(255) |           |          |
  #key_type           | character varying(255) |           |          |
  #direction_cardinal | character varying(255) |           |          |
  ##direction_degrees  | character varying(255) |           |          |
  #notes              | character varying(255) |           |          |

  if (!$$row{rbid}) {
    print "No rbid\n";
    next;
  }
  print "Looking for company $$row{rbid} for $$row{name}\n";
  my $company = openprint::Company->find_one(accountnumber=>$$row{rbid});
  if (!$company) {
    print "No company for $$row{rbid} for $$row{name}, assigning rhinobee\n";
    $company = $rhinobee;
  }
  $$row{name} = openprint::Host->transform(name=>$$row{name});
  my $host = openprint::Host->find_one(name=>$$row{name});

  if (!$host) {
    if (confirm("Add host for $$row{name}? Y|n ?", 'Y')) {
      $host = new openprint::Host();
      $host->save({name=>$$row{name}, abbr_name=>$$row{abbr_name}, type=>'Relay', owner_id=>$company->id()})
    } else {
      next;
    }
  } else {
    if ($$host{owner_id} != $company->id()) {
      if (confirm("Owner id doesn't match $$host{owner_id} != $$company{id}, update? Y|n", 'Y')) {
        $host->save({owner_id=>$company->id()});
      }
    }
  }

  foreach my $info (qw(relay_type relay_class battery_box bb_quantity ssid key key_type direction_cardinal direction_degrees)) {
    my $Info = $host->Info($info);
    if (!$Info) {
      $Info = new openprint::Host_Info();
      $Info->save({host_id=>$host->id(), name=>$info, value=>$$row{$info}});
    } elsif ($Info->value() ne $$row{$info}) {
      if (confirm("Update $info from $$Info{value} to $$row{$info}", 'Y')) {
        $Info->save({value=>$$row{$info}});
    }
    }
  }
} # end foreach relay

$dbh1->disconnect();
$dbh2->disconnect();

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
