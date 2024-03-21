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
my $dbh1 = sql::open_sql( $log, (database=>'freeside', driver=>'Pg',login=>'eepstein', password=>'ThDfoa7PL3AK6LHQaBgP74hRD5XfYvw8cock4RMOieE=', host=>'10.88.0.70') );
my $dbh2 = $openprint::dbh = sql::open_sql( $log, (database=>'rhinobee', driver=>'Pg',login=>'rhinobee', password=>'rhinobee', host=>'localhost') );

my $rhinobee = openprint::Company->find_one(name=>'Rhinobee');

my %classes = sql::execute(undef, $dbh1, 'SELECT classnum, classname FROM contact_class');

#custnum | agentnum | agent_custid | classnum |                      custbatch                      |              last              |           first           | ss | stateid | stateid_state | national_id | birthdate | spouse_birthdate | anniversary_date | signupdate | dundate |                         company                          | address1 | address2 | city | county | state | zip | country | latitude | longitude | coord_auto |     daytime      |    night     |     fax      |    mobile    | ship_last | ship_first | ship_company |            ship_address1             |      ship_address2      |     ship_city      | ship_county | ship_state |  ship_zip  | ship_country | ship_latitude | ship_longitude | ship_coord_auto | ship_daytime | ship_night | ship_fax | ship_mobile | payby |   payinfo   | paycvv | paymask |  paydate   | paystart_month | paystart_year | payissue |                    payname                    | paystate | paytype | payip | geocode | censustract | censusyear | district | tax | otaker | usernum | refnum | referral_custnum |                                                             comments                                                              | spool_cdr | squelch_cdr | cdr_termination_percentage |    invoice_terms     | credit_limit | archived | email_csv_cdr | accountcode_cdr | billday | prorate_day | edit_subject | locale | calling_list_exempt | invoice_noemail | addr_clean | ship_addr_clean | message_noemail | bill_locationnum | ship_locationnum | salesnum |    spouse_last    |  spouse_first  | cf_wirelesscustomernumber

my @custs = sql::execute_hash(undef, $dbh1, 'SELECT * FROM cust_main');
foreach my $cust (@custs) {
  next if !$$cust{custnum};

  my $company = openprint::Company->find_one(accountnumber=>$$cust{custnum});
  if (!$company) {
    $$cust{company} = openprint::Company->transform(name=>$$cust{company});
    $$cust{company} = $$cust{first}.' '.$$cust{last} if ! $$cust{company};
    $company = openprint::Company->find_one(name=>$$cust{company});
    if (! $company and confirm("Add company for $$cust{custnum} $$cust{company} [Y|n]", 'Y')) {
      $company = new openprint::Company();
      $company->save({
          name=>$$cust{company},
          accountnumber => $$cust{custnum},
          state=>$$cust{stateid_state},
          country=>$$cust{country},
        });
    }
  }
  next if ! $company;

  my @contacts = sql::execute_hash(undef, $dbh1, 'SELECT * FROM contact WHERE custnum=?', $$cust{custnum});
  #contactnum | prospectnum | custnum | locationnum |last|first|title|comment| disabled | classnum | selfservice_access | _password | _password_encoding
  print "We have ".@contacts." contacts\n";
  foreach my $row (@contacts) {
    my $user = openprint::User->find_one(company_id=>$company->id(), firstname=>$$row{first}, lastname=>$$row{last});
    if (!$user) {
      if (confirm("No user found for $$company{name} $$row{first} $$row{last} $$row{title} $classes{$$row{classnum}}, add? [Y|n]", 'Y')) {
        $user = new openprint::User();
        $_ = $user->save({company_id=>$company->id(), firstname=>$$row{first}, lastname=>$$row{last},
            title=>$$row{title},
            web_active=>($$row{selfservice_access}?'Y':'N'),
            notes => $$row{comment},
          });
        die $_ if $_;
      }
    } else {
      my @changes = $user->changes({
            title=>$$row{title},
          web_active=>($$row{selfservice_access}?'Y':'N'),
          notes => $$row{comment},
        });

      if (@changes and confirm("Apply @changes for $$company{name} $$row{first} $$row{last}?", 'Y')) {
        $user->save({
            title=>$$row{title},
            web_active=>($$row{selfservice_access}?'Y':'N'),
            notes => $$row{comment},
          });
      }
    } # end if user or not
    if ($user) {
      my @emails = sql::execute(undef, $dbh1, 'SELECT emailaddress FROM contact_email where contactnum=? ORDER BY emailaddress', $$row{contactnum});
      if (@emails==1) {
        if ($user->email() ne $emails[0]) {
          if (confirm("Update emails address from $$user{email} to $emails[0] for $$company{name} $$row{first} $$row{last}?", 'Y')) {
            $user->save({email=>$emails[0]});
          }
        }
      }
    }

  } # end foreach contact
} # end foreach cust

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
