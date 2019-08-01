#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;
use warnings;
use 5.10.0;
use utf8;
use File::Basename qw(basename);

require configuration;
require sets;
require sql;
require logger;
require misc;
use Getopt::Long;
require Date::Calc;
require Text::CSV_XS;
require openprint::Expense;
require openprint::Expense_Account;
require openprint::Expense_Rule;

use openprint ();
use vars qw($log $dbh %config %session);
*dbh = \$openprint::dbh;
*log = \$openprint::log;
*config = \%openprint::config;
*session = \%openprint::session;

my $program = 'import_bank_statements';
$log = logger->new('debug');
my $opts = {};
GetOptions($opts, 'help',
  'db_name=s',
  'db_host=s',
  'db_user=s',
  'db_pass=s',
  'debug=s',
  'file=s',
  'account=s',
  'Currency=s',
  'format=s');

if ( $opts->{help} ) {
  usage();
  exit 0;
}
if ( $opts->{debug}) {
  $$log{level} = $opts->{debug};
}
$_ = configuration::from_file("/etc/openprint/$program.conf");
$log->error($_) if $_;
configuration::merge($opts);

unless ($config{db_name}) {
  print STDERR "$program: missing required --db_name parameter\n";
  exit 1;
}

$dbh = sql::open_sql( $log,
        host      => $config{db_host},
        database  => $config{db_name},
        driver    => 'Pg',
        login     => $config{db_user},
        password  => $config{db_pass},
        );

die 'Error opening db' if ! $dbh;
configuration::init();
$_ = configuration::from_file("/etc/openprint/$program.conf");
$log->error($_) if $_;
configuration::merge($opts);

openprint::session_init();

foreach my $opt ( 'account', 'format' ) {
  die "No $opt given" if !$$opts{$opt};
}

my $Account = openprint::Expense_Account->find_one(name=>$$opts{account});
if ( ! $Account ) {
  die "No account found for $$opts{account}\n";
}
if ( ! $openprint::Owner->id() ) {
  die "Need an owner\n";
}

my $from_id=2;
my $to_id=1;

$log->debug('Loading rules');
my @Rules = openprint::Expense_Rule->find();
$log->debug(@Rules . ' loaded');

# Track expenses added this run, to help with duplicates
my %Expenses_Added;

my $csv = Text::CSV_XS->new();
open ( FH, "$$opts{file}" ) or die "Can't open $$opts{file} : $!";
  if ( $$opts{format} eq 'CDNTire' ) {
    <FH>;
    <FH>;
    <FH>;
    <FH>;
  }

while ( <FH> ) {
  my $status = $csv->parse($_);

  # Create an object with the data from the line
  my $Expense = new openprint::Expense();
  delete $$Expense{id};
  my ($date, $time, $card, $amount, $desc, $debit, $credit, $balance, $paid_on, $type, $posted, $ref );

  if ( $$opts{format} eq 'CIBC' ) {
    ($date, $desc, $debit, $credit, $card) = misc::trim($csv->fields());

    $paid_on = $date,
    $amount = $debit;

    $Expense->set_no_defaults({
      description => $desc,
      account_id  => $$Account{id},
      total       => $debit,
      paid_on     => $paid_on,
    });
} elsif ( $$opts{format} eq 'TD' ) {
    ($date, $desc, $debit, $credit, $balance) = misc::trim($csv->fields());

    my ($month, $day, $year) = split('/', $date);
    $paid_on = join('-', $year, $month, $day);
    $amount = $debit;

    $Expense->set_no_defaults({
      description => $desc,
      account_id  => $$Account{id},
      total       => $debit,
      paid_on     => $paid_on,
    });
  } elsif ( $$opts{format} eq 'PC' ) {
    #( $desc, $card, $date, $time, $amount) = misc::trim($csv->fields()); OLD
    ( $desc, $type, $card, $date, $time, $amount) = misc::trim($csv->fields());
    next if $desc eq "Merchant Name";
    next if $desc eq "Description";
    $debit = $amount;

    my ($month, $day, $year) = split('/', $date);
    $paid_on = join('-', $year, $month, $day);

    $Expense->set_no_defaults({
      description => $desc,
      account_id  => $$Account{id},
      total       => $amount,
      paid_on     => $paid_on,
    });
  } elsif ( $$opts{format} eq 'CDNTire' ) {
    ( $ref, $date, $posted, $type, $desc, $amount) = misc::trim($csv->fields());
    $debit = $amount;

    $Expense->set_no_defaults({
      description => $desc,
      account_id  => $$Account{id},
      total       => $amount,
      paid_on     => $date,
    });

  } else {
    die "Unknown format $$opts{format}";
  } # end if format

  if ( $amount > 0 ) {

    my $response;

    my $matched = 0;
    foreach my $Rule ( @Rules ) {
      if ( $Rule->match({desc=>$desc, date=>$date, amount=>$amount, debit=>$debit, credit=>$credit, balance=>$balance}) ) {
        if ( 0 ) {
          print "Apply rule $$Rule{name} for $date, $desc, $debit, $credit, $balance ? [Y|n]";
          $response = <STDIN>;
          chomp $response;
          if ( (!$response) or ($response =~ /[Yy]/) ) {
            $matched = 1;
            $Rule->apply($Expense);
            last;
          }
        } else {
            $matched = 1;
          $Rule->apply($Expense);
          last;
        }
      } # end if matched
    } # end foreach Rule

    $log->info("No rules matched") if !$matched;

    my %expense_find = %$Expense;

    if ( $expense_find{recipient} ) {
      $expense_find{'recipient lc'} = lc $expense_find{recipient};
      delete $expense_find{recipient};
    } 
    if ( $expense_find{paid_on} ) {
      my ( $year, $month, $day ) = split('-', $expense_find{paid_on});
      $expense_find{'paid_on >='}    = join('-', Date::Calc::Add_Delta_Days(1*$year, 1*$month, 1*$day,-3));
      $expense_find{'paid_on <='}    = join('-', Date::Calc::Add_Delta_Days(1*$year, 1*$month, 1*$day,3));
      delete $expense_find{paid_on};
    }
    my @Expenses = openprint::Expense->find(\%expense_find);

    if ( @Expenses ) {
      $log->info(@Expenses . "Found an expense @Expenses that looks like it matches: \n" . join("\n", map { $_->to_string() } @Expenses));
      @Expenses = map { $Expenses_Added{$$_{id}} ? () : $_ } @Expenses;
      if ( @Expenses ) {
        $log->info("Found an expense after filtering that looks like it matches: \n" . join("\n", map { $_->to_string() } @Expenses));
        next;
      }
    } elsif ( $matched ) {
      ## Look for it without the description, but with a transaction id
      delete $expense_find{description};
      @Expenses = openprint::Expense->find(\%expense_find);
      if ( @Expenses ) {
        $log->info("Found an expense after filtering that looks like it matches:\n" . join("\n", map { $_->to_string() } @Expenses));
        next;
      } else {
        delete %expense_find{'paid_on >='};
        delete %expense_find{'paid_on <='};
        $expense_find{paid_on} = undef;
        @Expenses = openprint::Expense->find(\%expense_find);
        if ( @Expenses ) {
          foreach my $E ( @Expenses ) {
             print "Update record for? " . $E->to_string()." [Y|n]";
             $response = <STDIN>;
             chomp $response;
             if ( (!$response) or ($response =~ /[Yy]/) ) {

               $_ = $E->save({
                   paid_on     =>  $paid_on,
                 });
               if ( $_ ) {
                 die $_;
               }
               $Expenses_Added{$$Expense{id}} = $Expense;
             }
          }
          next;
        }
      }
    } 
    $log->info("No expenses found to match $date, $desc, $debit, $credit, $balance, rules? " . @Rules . "\n" . $Expense->to_string());

    print "Add record for? [Y|n]";
    $response = <STDIN>;
    chomp $response;
    if ( (!$response) or ($response =~ /[Yy]/) ) {

      $_ = $Expense->save({
          account_id  =>  $$Account{id},
          amount      =>  $amount,
          paid_on     =>  $paid_on,
          invoiced_on =>  $paid_on,
          due_on      =>  $paid_on,
          description =>  $desc,
          owner_id    =>  $$openprint::Owner{id},
          currency_id =>  $$openprint::Currency{id},
        });
      if ( $_ ) {
        die $_;
      }
      $Expenses_Added{$$Expense{id}} = $Expense;
    }

  } else {
    $log->error("No credit or debit? ");
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

  --debug
  --file =s		File to import
  account=s
  Currency=s
  format=s
	

EOH
}
1;
__END__
