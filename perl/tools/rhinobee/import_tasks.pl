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
require openprint::Task;

use openprint ();
use vars qw( $log );
*log = \$openprint::log;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
my $dbh1 = sql::open_sql( $log, (database=>'rbd', driver=>'Pg',login=>'webuser', password=>'bigbizDB!007', host=>'10.88.8.3') );
my $dbh2 = $openprint::dbh = sql::open_sql( $log, (database=>'rhinobee', driver=>'Pg',login=>'rhinobee', password=>'rhinobee', host=>'localhost') );

my $rhinobee = openprint::Company->find_one(name=>'Rhinobee');
my @contacts = sql::execute_hash(undef, $dbh1, 'SELECT * FROM tasks');
print "We have ".@contacts." contacts\n";
foreach my $row (@contacts) {
  #Column    |            Type             | Collation | Nullable |              Default
  #-------------+-----------------------------+-----------+----------+-----------------------------------
  #id          | integer                     |           | not null | nextval('tasks_id_seq'::regclass)
  #tag_id      | integer                     |           |          |
  #action_id   | integer                     |           |          |
  #title       | character varying(255)      |           |          |
  #notes       | text                        |           |          |
  #rb_id       | integer                     |           |          |
  #owner_id    | integer                     |           |          |
  #deadline    | date                        |           |          |
  #type_id     | integer                     |           |          |
  #ntf_2       | character varying(255)      |           |          |
  #created_at  | timestamp(6) with time zone |           |          | now()
  #created_by  | character varying(255)      |           |          |
  #modified_at | timestamp(6) with time zone |           |          | now()
  #modified_by | character varying(255)      |           |          |
  #ch_1        | character varying(255)      |           |          |
  #ch_2        | character varying(255)      |           |          |
  #ch_3        | character varying(5000)     |           |          |
  #ch_4        | character varying(255)      |           |          |
  #ch_5        | character varying(255)      |           |          |
  #ch_6        | character varying(255)      |           |          |
  #ch_7        | character varying(255)      |           |          |
  #ch_8        | character varying(255)      |           |          |
  #ch_9        | character varying(255)      |           |          |
  #ch_10       | character varying(255)      |           |          |
  #ch_11       | character varying(255)      |           |          |
  #ch_12       | character varying(255)      |           |          |
  #ch_13       | character varying(255)      |           |          |
  #ch_14       | character varying(255)      |           |          |
  #
  
  next if $$row{id} < 1099;
    $$row{department_id} = $$row{tag_id};
    $$row{created_on} = $$row{created_at};
    $$row{updated_on} = $$row{modified_at};

    if ($$row{created_by}) {
      my $updater = openprint::User->find_one(type=>['A','E'], firstname=>$$row{created_by});
      if ($updater) {
        $$row{createdby_id} = $updater->id();
      } elsif (confirm('Add User '.$$row{created_by}.'[Y|n]', 'Y')) {
        $updater = new openprint::User();
        $updater->save({type=>'E', company_id=>$rhinobee->id(), firstname=>$$row{created_by}});
        $$row{createdby_id} = $updater->id();
      }
    }
    if ($$row{modified_by}) {
      my $updater = openprint::User->find_one(type=>['E','A'], firstname=>$$row{modified_by});
      if ($updater) {
        $$row{updatedby_id} = $updater->id();
      } elsif (confirm('Add User '.$$row{modified_by}.'[Y|n]', 'Y')) {
        $updater = new openprint::User();
        $updater->save({type=>'E', company_id=>$rhinobee->id(), firstname=>$$row{modified_by}});
        $$row{updatedby_id} = $updater->id();
      }
    }


  my $task = openprint::Task->find_one(id=>$$row{id});
  if ($task) {
    my @changes = $task->changes($row);
    if (@changes and confirm("Update task $$row{id} as follows: [Y|n]\n".join("\n", @changes),'Y')) {
      $task->save($row);
    }
  } else {
    $task = new openprint::Task();
    $task->save($row, 1);
  }
      #$company->save({accountnumber=>$$row{rb_id}});
	
} # end foreach row
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
