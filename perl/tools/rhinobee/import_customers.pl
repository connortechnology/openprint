#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use utf8;
use strict;
use Encode;

require sql;
require logger;
require openprint::Object;
require openprint::Company;
require openprint::User;

use openprint ();
use vars qw( $log );
*log = \$openprint::log;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
my $dbh1 = sql::open_sql( $log, (database=>'rbd', driver=>'Pg',login=>'webuser', password=>'bigbizDB!007', host=>'10.88.8.3') );
my $dbh2 = $openprint::dbh = sql::open_sql( $log, (database=>'rhinobee', driver=>'Pg',login=>'rhinobee', password=>'rhinobee', host=>'localhost') );

my @contacts = sql::execute_hash(undef, $dbh1, 'SELECT * FROM audited_contact_list');
print "We have ".@contacts." contacts\n";
foreach my $row (@contacts) {
  print "$row\n";
  #Column         |            Type             | Collation | Nullable |                    Default
          #-----------------------+-----------------------------+-----------+----------+------------------------------------------------
#id                    | integer                     |           | not null | nextval('audited_customer_list_seq'::regclass)
 #first_name            | character varying(255)      |           |          |
 #last_name             | character varying(255)      |           |          |
 #company_name          | character varying(255)      |           |          |
 #rb_id                 | integer                     |           |          |
 #billing_addr          | character varying(255)      |           |          |
 #service_addr          | character varying(255)      |           |          |
 #city                  | character varying(255)      |           |          |
 #state                 | character varying(255)      |           |          |
 #zip                   | character varying(255)      |           |          |
 #phone                 | character varying(255)      |           |          |
 #email                 | character varying(255)      |           |          |
 #ip_addr               | character varying(255)      |           |          |
 #nagios_name           | character varying(255)      |           |          |
 #is_active             | character varying(255)      |           |          |
 #created_at            | timestamp(6) with time zone |           |          | now()
 #created_by            | character varying(255)      |           |          |
 #modified_at           | timestamp(6) with time zone |           |          | now()
 #modified_by           | character varying(255)      |           |          |
 #rate                  | character varying(255)      |           |          |
 #plan                  | character varying(500)      |           |          |
 #comp                  | character varying(255)      |           |          |
 #actual_bandwidth_down | integer                     |           |          |
 #actual_bandwidth_up   | integer                     |           |          |
 #date_active           | date                        |           |          |
 #date_cancel           | date                        |           |          |
 #date_hold_start       | date                        |           |          |
 #date_hold_end         | date                        |           |          |
 #reason                | character varying(1500)     |           |          |
 #equipment_on_premise  | character varying(255)      |           |          |
 #notes                 | character varying(1500)     |           |          |


if (!$$row{company_name}) {
  print "No name\n";
  next;
}
  print "Looking for company $$row{id} $$row{company_name}\n";
  $$row{company_name} = ssi::unhtmlize(Encode::encode_utf8($$row{company_name}));
  print "Looking for company after encode $$row{company_name}\n";
  $$row{company_name} =~ s/^&amp;//;
  print "Looking for company after strip &amp $$row{company_name}\n";
  $$row{company_name} =~ s/^\W*&\s*//g;
  print "Looking for company after strip & $$row{company_name}\n";
  $$row{company_name} =~ s/[^\x{0000}-\x{007F}]+/ /g;
  print "Looking for company $$row{company_name}\n";
  $$row{company_name} = openprint::Company->transform(name=>$$row{company_name});
  print "Looking for company $$row{company_name}\n";

  $$row{email} = ssi::unhtmlize(Encode::encode_utf8($$row{email}));
  $$row{email} =openprint::User->transform(email=>$$row{email});

  $$row{first_name} = openprint::User->transform(firstname=>ssi::unhtmlize(Encode::encode_utf8($$row{first_name})));
  $$row{last_name} = openprint::User->transform(firstname=>ssi::unhtmlize(Encode::encode_utf8($$row{last_name})));

  if (!$$row{company_name}) {
    if ( $$row{first_name} or $$row{last_name}) {
      $$row{company_name} = $$row{first_name};
      $$row{company_name} .=' ' if $$row{company_name};
     $$row{company_name} .= $$row{last_name};
    }
  }

  my ($address, $city, $state, $zip) = $$row{billing_addr} =~ /^(.*)\n(.+),? (\w\w) (\d{5})$/gm;
  $$row{city} = $city if !$$row{city};
  $$row{state} = uc $state if ! $$row{state};
  $$row{zip} = $zip if ! $$row{zip};
  print "Have $address, $city, $state, $zip form $$row{billing_addr}\n";

  my $company = openprint::Company->find_one('name lc'=>lc $$row{company_name}, accountnumber=>$$row{rb_id});
  $company = openprint::Company->find_one('name lc'=>lc $$row{company_name}) if !$company;
  if (!$company) {
      if (confirm("Add $$row{company_name}", 'Y')) {
        $company = new openprint::Company();
        $company->save({name=>$$row{company_name},
            city=>Encode::encode_utf8($$row{city}),
            state=>Encode::encode_utf8($$row{state}),
            postalcode=>Encode::encode_utf8($$row{zip}),
            phone=>Encode::encode_utf8($$row{phone}),
            accountnumber=>$$row{rb_id}
          });
      } else {
        next;
      }
  } else {
    if (!$company->accountnumber()) {
      $company->save({accountnumber=>$$row{rb_id}});
    }
    my @changes = $company->changes({ city=>$$row{city}, state=>$$row{state}, postalcode=>$$row{zip}});
    if (@changes) {
      if (confirm("Apply @changes? Y|n", 'Y')) {
        $company->save({city=>$$row{city}, state=>$$row{state}, postalcode=>$$row{zip}});
      }
      for my $k ('rate','plan','comp','actual_bandwidth_down','actual_bandwidth_up','date_active','date_cancel','date_hold_start','date_hold_end','reason','equipment_on_premise') {

        if (!$company->$k() ne $$row{$k}) {
          $company->$k($$row{$k});
        }
      } # end foreach profile filed
    }
    my $billing_location = openprint::Location->find_one(company_id=>$company->id(), address=>$address, postalcode=>$zip,
      name=>$$company{name}.' Billing Address');
    if (!$billing_location) {
      openprint::Location::save_location({
          city=>$city, state=>$state, postalcode=>$zip,
          company_id=>$company->id(), address=>$address,
          location=>$$company{name}.' Billing Address'});
    } else {
      if (!$billing_location->parent_id()) {
        my $city_loc = openprint::Location->find_one(name=>$city, type=>'city');
        if ($city_loc) {
          $billing_location->save({parent_id=>$city_loc->id()});
        }
      }
    }
    ($address, $city, $state, $zip) = $$row{service_addr} =~ /^(.*)\n(.+),? (\w\w) (\d{5})$/gm;

    my $service_location = openprint::Location->find_one(company_id=>$company->id(), address=>$address, postalcode=>$zip,
      name=>$$company{name}.' Service Address');
    if (!$service_location) {
      openprint::Location::save_location({
          city=>$city, state=>$state, postalcode=>$zip,
          company_id=>$company->id(), address=>$address,
          location=>$$company{name}.' Service Address'});
    } else {
      if (!$service_location->parent_id()) {
        my $city_loc = openprint::Location->find_one(name=>$city, type=>'city');
        if ($city_loc) {
          $service_location->save({parent_id=>$city_loc->id()});
        }
      }
    }
  }
  my $user = openprint::User->find_one(email=>$$row{email});
  if (!$user) {
    if (confirm("Add User $$row{first_name} $$row{last_name}", 'Y')) {
      $user = new openprint::User();
      $user->save({firstname=>$$row{first_name}, lastname=>$$row{last_name}, company_id=>$$company{id},
          email=>$$row{email},
          phone=>Encode::encode_utf8($$row{phone}),
        });
    }
  }

	
} # end foreach contact
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
