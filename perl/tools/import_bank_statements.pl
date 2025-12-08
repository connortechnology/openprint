#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;
use warnings;
use 5.10.0;
use utf8;
use File::Basename qw(basename);
use Data::Dumper;
use Encode qw(decode encode);

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
my $options = {};
GetOptions($options, 'help',
  'config=s',
  'db_name=s',
  'db_host=s',
  'db_user=s',
  'db_pass=s',
  'debug=s',
  'file=s',
  'account=s',
  'Currency=s',
  'format=s');

if ( $options->{help} ) {
  usage();
  exit 0;
}

if ( ! $$options{file} and @ARGV ) {
  $$options{file} = $ARGV[0];
  #print "Setting file to $$options{file}\n";
}

open(FH, $$options{file}) or die "Can't open $$options{file} : $!";

if ( $options->{debug}) {
  $$log{level} = $options->{debug};
}
$_ = configuration::from_file($$options{config} ? $$options{config} : "/etc/openprint/$program.conf");
$log->error($_) if $_;
configuration::merge($options);

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
configuration::merge($options);

openprint::session_init();

my $USD = openprint::Currency->find_one(short=>'USD');
my $CAD = openprint::Currency->find_one(short=>'CAD');

while ( !($$options{account} and openprint::Expense_Account->find_one(name=>$$options{account})) ) {
  my $guessed_account = '';
  my @accounts = openprint::Expense_Account->find(order=>'lower(name)');
  if ( @accounts == 1 ) {
    $$options{account} = $accounts[0]{name};
    print "Selecting $$options{account} for the account:\n";
    last;
  } else {

    if ( $$options{file} =~ /Transactions(.*)\.csv$/ ) {
      $guessed_account = 'CDT Mastercard 9122 3629';
    } elsif ( $$options{file} =~ /report(.*)\.csv$/ ) {
      $guessed_account = 'PC Mastercard 6369';
      print "Guessing account to " . $guessed_account. "\n";
    } elsif ( $$options{file} =~ /download(.*)\.csv$/ ) {
      $guessed_account = 'Meridian Joint';
    }
  }
  my %accounts = map { $$_{id} => $_ } @accounts;
  print "Please select the account:\n";
  foreach ( @accounts ) {
    print '['.$$_{id}.'] '.$$_{name}.($$_{name} eq $guessed_account ? ' < ':'')."\n";
  }
  my $response = <STDIN>;
  chomp $response;
  if ( $response and $accounts{$response} ) {
    $$options{account} = $accounts{$response}{name};
  } elsif ( (! $response) and $guessed_account ) {
    $$options{account} =  $guessed_account;
  } else {
    print "Invalid entry\n";
  }
}

my $Account = openprint::Expense_Account->find_one(name=>$$options{account});
if ( ! $Account ) {
  die "No account found for $$options{account}\n";
}
if ( ! $openprint::Owner->id() ) {
  die "Need an owner\n";
} else {
  print "Owner_id is $$openprint::Owner{id}\n";
}

my $guessed_format='';
if ( $$options{file} =~ /Transactions(.*)\.csv$/ ) {
  $guessed_format = 'CDNTire';
} elsif ( $$options{file} =~ /accountactivity(.*)\.csv$/ ) {
  $guessed_format = 'TD';
} elsif ( $$options{file} =~ /cibc(.*)\.csv$/ ) {
  $guessed_format = 'CIBC';
} elsif ( $$options{file} =~ /download(.*)\.csv$/ ) {
  $guessed_format = 'Meridian';
} elsif ( $$options{file} =~ /report(.*)\.csv$/ ) {
  $guessed_format = 'PC';
} elsif ( $$options{file} =~ /Download\.CSV$/ ) {
  $guessed_format = 'Paypal';
} elsif ( $$options{file} =~ /csv(\d+)\.csv$/ ) {
  $guessed_format = 'RBC';
}
print "Guessed format is $guessed_format\n";

my @formats = ('CDNTire', 'CIBC', 'PC', 'TD', 'Meridian','Paypal','RBC');
while ( !( $$options{format} and sets::isin($$options{format}, \@formats) ) ) {
  print "Please select the format:\n";
  for ( my $i = 0; $i < @formats; $i += 1 ) {
    print '['.$i.'] '.$formats[$i].($formats[$i] eq $guessed_format ? ' < ':'')."\n";
  }
  my $response = <STDIN>;
  chomp $response;
  if ( ($response ne '') and $formats[$response] ) {
    $$options{format} = $formats[$response];
  } elsif ( (! $response) and $guessed_format ) {
     $$options{format} =  $guessed_format;
   } else {
    print "Invalid entry\n";
  }
} # end while ! format

my $from_id=2;
my $to_id=1;

my @Rules = openprint::Expense_Rule->find();

# Track expenses added this run, to help with duplicates
my %Expenses_Added;
my @columns;

my $csv = Text::CSV_XS->new();
if ($$options{format} eq 'CDNTire') {
  <FH>;
  <FH>;
  <FH>;
  my $line = <FH>;
  #if ( ! utf8::is_utf8($line) ) {
    utf8::encode($line);
    print "was unicode $line\n";
    #}
  $csv->parse($line);
  @columns = $csv->fields();
} elsif ($$options{format} eq 'Paypal') {
  my $line = <FH>;
  $line =~ s/[^[:ascii:]]//g;
  my $status = $csv->parse($line);
  die $csv->error_diag() if !$status;
  @columns = $csv->fields();
} elsif ($$options{format} eq 'RBC') {
  my $line = <FH>;
}

LINE: while ( my $line = <FH> ) {
  if ( ! utf8::is_utf8($line) ) {
    utf8::decode($line);
    print "was unicode $line\n";
  }
  my $status = $csv->parse($line);

  # Create an object with the data from the line
  my $Expense = new openprint::Expense();
  $$Expense{owner_id}    =  $$openprint::Owner{id};
  delete $$Expense{id};

  my ($date, $time, $card, $amount, $desc, $desc1, $desc2, $desc3, $debit, $credit, $balance, $paid_on, $type, $posted, $ref, $cad, $usd );

  if ( $$options{format} eq 'CIBC' ) {
    ($date, $desc, $debit, $credit, $card) = misc::trim($csv->fields());

    $paid_on = $date,
    $amount = $debit ? $debit : -1*$credit;

    $Expense->set_no_defaults({
      description => $desc,
      account_id  => $$Account{id},
      total       => $amount,
      paid_on     => $paid_on,
    });
  } elsif ( $$options{format} eq 'TD' ) {
    ($date, $desc, $debit, $credit, $balance) = misc::trim($csv->fields());

    my ($month, $day, $year) = split('/', $date);
    $paid_on = join('-', $year, $month, $day);
    $amount = ($debit ? $debit : -1*$credit);

    $Expense->set_no_defaults({
      description => $desc,
      account_id  => $$Account{id},
      total       => $amount,
      paid_on     => $paid_on,
    });
  } elsif ( $$options{format} eq 'Meridian' ) {
    #my  ID, Date, Account Name, Description1, Description2, Description3, Amount, Balance
    #653656564,2019-11-20 12:00:00 AM,2471118-Maximiser - 0,"Cheque 27",,,-3100,37.49
    ( $ref, $date, $card, $desc1, $desc2, $desc3, $amount, $balance ) = misc::trim($csv->fields());
    next if $date eq 'Date';
    ($paid_on) = $date =~ /^(\d{4}\-\d{2}\-\d{2})/;
    $desc = join("\n", $desc1, $desc2, $desc3);
    $amount *= -1;
    $log->debug("date: $paid_on desc: $desc amount:$amount");
    $Expense->set_no_defaults({
      description => $desc,
      account_id  => $$Account{id},
      total       => $amount,
      paid_on     => $paid_on,
    });
  } elsif ($$options{format} eq 'RBC') {
    #"Account Type","Account Number","Transaction Date","Cheque Number","Description 1","Description 2","CAD$","USD$"
    (undef, undef, $date, $ref, $desc1, $desc2, $cad, $usd) = misc::trim($csv->fields());
    my ($month, $day, $year) = split('/', $date);
    $paid_on = join('-', $year, $month, $day);
    $desc = join(' ', ($desc1 ?$desc1:()), ($desc2?$desc2:()));

    $Expense->set_no_defaults({
      description => $desc,
      account_id  => $$Account{id},
      paid_on     => $paid_on,
      total_locked=> 1,
    });
    if ($cad) {
      $Expense->currency_id($CAD->id());
      $amount = $Expense->total(-1*$cad);
    } else {
      $Expense->currency_id($USD->id());
      $amount = $Expense->total(-1*$usd);
    }

  } elsif ( $$options{format} eq 'PC' ) {
    #( $desc, $card, $date, $time, $amount) = misc::trim($csv->fields()); OLD
    ( $desc, $type, $card, $date, $time, $credit) = misc::trim($csv->fields());
    next if $desc eq 'Merchant Name';
    next if $desc eq 'Description';

    my ($month, $day, $year) = split('/', $date);
    $paid_on = join('-', $year, $month, $day);
    $amount = $debit = -1*$credit;

    $Expense->set_no_defaults({
      description => $desc,
      account_id  => $$Account{id},
      total       => $amount,
      paid_on     => $paid_on,
    });
  } elsif ( $$options{format} eq 'CDNTire' ) {

    if ( @columns == 6 ) {
      ( $ref, $date, $posted, $type, $desc, $amount) = misc::trim($csv->fields());
    } elsif ( @columns == 7 ) {
      ( $ref, $date, $posted, $type, $desc, undef, $amount) = misc::trim($csv->fields());
    } else {
      die 'Invalid # of columns ' . scalar @columns . " @columns";
    }
    $debit = $amount;
    $paid_on = $date;

    $Expense->set_no_defaults({
      description => $desc,
      account_id  => $$Account{id},
      total       => $amount,
      total_locked=> 1,
      paid_on     => $date,
    });
  } elsif ( $$options{format} eq 'Paypal' ) {
    my %data;
    print "columns: @columns\n";
    print "data: ". join(' ', misc::trim($csv->fields()));
    @data{@columns} = misc::trim($csv->fields());
    #"Date","Time","TimeZone","Name","Type","Status","Currency","Gross","Fee","Net","From Email Address","To Email Address","Transaction ID","Shipping Address","Address Status","Item Title","Item ID","Shipping and Handling Amount","Insurance Amount","Sales Tax","Option 1 Name","Option 1 Value","Option 2 Name","Option 2 Value","Reference Txn ID","Invoice Number","Custom Number","Quantity","Receipt ID","Balance","Address Line 1","Address Line 2/District/Neighborhood","Town/City","State/Province/Region/County/Territory/Prefecture/Republic","Zip/Postal Code","Country","Contact Phone Number","Subject","Note","Country Code","Balance Impact"
    print Data::Dumper::Dumper(\%data);


    my ( $d, $m, $y ) = split(/\//, $data{Date});
    $paid_on = $date = join('-', ( $y, $m, $d ));
    $desc = join("\n", map { $_ . ' = '. $data{$_} } sort { $a cmp $b } keys %data);
    $amount = $data{Net};
    $amount =~ s/[^\-0-9\.]//g;
    $amount = $amount * -1;

    my $currency = openprint::Currency->find_one(short=>$data{Currency});

    $Expense->set_no_defaults({
        ($currency ? (currency_id=>$currency->id()) : ()),
      description => $desc,
      account_id  => $$Account{id},
      total       => $amount,
      total_locked=> 1,
      paid_on     => $date,
      transaction_id=>$data{'Transaction ID'},
    });

    if ($data{'Balance Impact'} eq 'Credit' and $data{'From Email Address'}) {
      my $u = openprint::User->find_one(email=>$data{'From Email Address'});
      if (!$u) {
        if (confirm('Add user/company for '.$data{'From Email Address'}.'? [Y|n]', 'Y')) {

          my $company = openprint::Company->find_one(name=>$data{Name});
          if (!$company) {
            $company = new openprint::Company();
            $company->save({
                name=>$data{Name},
                address1 => $data{'Address Line 1'},
                address2 => $data{'Address Line 2'},
                country=>$data{'Country Code'},
                state => $data{'State/Province/Region/County/Territory/Prefecture/Republic'},
                phone => $data{'Contact Phone Number'},
                city  => $data{'Town/City'},
                postalcode  =>$data{'Zip/Postal Code'},
              });
          }
          $u = new openprint::User();
          $u->save({
              name=>$data{Name},
              company_id=>$company->id(),
              email=>$data{'From Email Address'},
            });
          $Expense->recipient_id($company->id());
        }
      } else {
        $log->debug("Setting recipient to ".$u->Company()->name() ." from From ".$u->email());
        $Expense->recipient_id($u->company_id());
      }
    } # end if From Email Address
    if ($data{'Balance Impact'} eq 'Debit' and $data{'To Email Address'}) {
      my $u = openprint::User->find_one(email=>$data{'To Email Address'});
      if (!$u) {
        if (confirm('Add user/company for '.$data{'To Email Address'}.'? [Y|n]', 'Y')) {
          my $company = openprint::Company->find_one(name=>$data{Name});
          if (!$company) {
            $company = new openprint::Company();
            $company->save({
                name=>$data{Name},
                address1 => $data{'Address Line 1'},
                address2 => $data{'Address Line 2'},
                country=>$data{'Country Code'},
                state => $data{'State/Province/Region/County/Territory/Prefecture/Republic'},
                phone => $data{'Contact Phone Number'},
                city  => $data{'Town/City'},
                postalcode  =>$data{'Zip/Postal Code'},
              });
          }
          $u = new openprint::User();
          $u->save({
              name=>$data{Name},
              company_id=>$company->id(),
              email=>$data{'To Email Address'},
            });
          $Expense->recipient_id($company->id());
        }
      } else {
        $log->debug("Setting recipient to ".$u->Company()->name() ." from To ".$u->email());
        $Expense->recipient_id($u->company_id());
      }
    } # end if To Email Address

  } else {
    die "Unknown format $$options{format}";
  } # end if format

  if ( $Expense->{total} ) {
    my $response;

    while ( 1 ) {
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

      $log->info('No rules matched') if !$matched;

      #$Expense->Taxes(undef); # Need to redo taxes or else business_use_amount won't calc right
      #But deleting the tax entries removes the charged setting.

      $Expense->amount(undef) if ! $$Expense{amount_locked};
      $Expense->business_use_amount(undef);
      $Expense->total(undef) if ! $$Expense{total_locked};
      my %expense_find = %$Expense;
      delete $expense_find{business_use_amount};
      delete $expense_find{total_locked};
      delete $expense_find{category} if $expense_find{category_id};

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
      if ( $expense_find{description} ) {
        $expense_find{'description ilike'} = $expense_find{description}.'%';
        delete $expense_find{description};
      }
      delete $expense_find{Taxes};
      if ($expense_find{Category}) {
        if ($expense_find{Category}->id() and ! $expense_find{category_id}) {
          $expense_find{category_id} = $expense_find{Category}->id();
        }
        delete $expense_find{Category};
      }
      my @Expenses = openprint::Expense->find(\%expense_find);

      if ( @Expenses ) {
        $log->info(@Expenses . "Found an expense @Expenses that looks like it matches: \n" . join("\n", map { $_->to_string() } @Expenses));
        @Expenses = map { $Expenses_Added{$$_{id}} ? () : $_ } @Expenses;
        if ( @Expenses ) {
          $log->info("Found an expense after filtering that looks like it matches: \n" . join("\n", map { $_->to_string() } @Expenses));
          next LINE;
        }
      } elsif ( $matched ) {
        ## Look for it without the description, but with a transaction id
        delete $expense_find{'description ilike'};
        #delete $expense_find{transaction_id};
        delete $expense_find{'recipient lc'};
        @Expenses = openprint::Expense->find(\%expense_find);
        if ( @Expenses ) {
          $log->info("Found an expense after filtering that looks like it matches:\n" . join("\n", map { $_->to_string() } @Expenses));
          next LINE;
        } else {
          #delete %expense_find{'paid_on >='};
          #delete %expense_find{'paid_on <='};
          #$expense_find{paid_on} = undef;
          @Expenses = openprint::Expense->find(\%expense_find);
          if ( @Expenses ) {
            foreach my $E ( @Expenses ) {
               if (confirm("WARNING Update paid_on to $paid_on record for? " . $E->to_string()." [y|N]", 'N')) {
                 $_ = $E->save({ paid_on     =>  $paid_on });
                 die $_ if $_;
                 #$Expenses_Added{$$Expense{id}} = $Expense;
               }
            } # end foreach Expense
            next LINE;
          }
        }
      } 
      $log->info("No expenses found to match $date, $desc, $debit, $credit, balance(".(defined $balance ? $balance : 'undef').")\n".$Expense->to_string());

      print 'Add record for? [Y|n|r]';
      $response = <STDIN>;
      chomp $response;
      if ( (!$response) or ($response =~ /[Yy]/) ) {

        $Expense->set({
            account_id  =>  $$Account{id},
            total       =>  $amount,
            paid_on     =>  $paid_on,
            invoiced_on =>  $paid_on,
            due_on      =>  $paid_on,
            description =>  $desc,
            owner_id    =>  $$openprint::Owner{id},
            ($$Expense{currency_id} ? () : (currency_id =>  $$openprint::Currency{id})),
            total_locked => 1,
          });
        $_ = $Expense->save({amount=>undef});
        if ( $_ ) {
          die $_;
        }
        $Expenses_Added{$$Expense{id}} = $Expense;
        last;
      } elsif ( $response =~ /[Rr]/ ) {
        @Rules = openprint::Expense_Rule->find();
        $log->debug(@Rules . ' loaded');
      } else {
        last;
      }
    } # end while 1
  } else {
    $log->error("No credit or debit? $line\n".join(',',$csv->fields()).'Press any key to continue');
    $_ = <STDIN>;
  }
  #sleep(1);
} # end while
close(FH);

$dbh->disconnect();

sub confirm {
  my $prompt = shift;
  my $default = @_ ? lc shift : 'y';
  print $prompt ? $prompt : "Confirm? (Y|n)";
  if ( $$options{y} ) {
    print "Y\n";
    return 1;
  }
  if ( $$options{n} ) {
    print "N\n";
    return 0;
  }
  $_=<STDIN>; chomp;
  return 1 if $_ and ( lc($_) eq 'y');
  return 1 if (!$_) and ($default eq 'y');
  return 0;
}

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
