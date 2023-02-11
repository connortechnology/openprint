#!/usr/bin/perl
use strict;
use warnings;
use lib '/var/www/testing/perl';

my $limit = 10;

require sql;
require misc;
require logger;

use Text::CSV_XS;

use vars qw( $log $dbh %config);
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
$openprint::log = logger->new();
$openprint::log->{level} = 'debug';

use Getopt::Long;
use File::Basename qw(basename);

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help',
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s', 'db_port=s',
    'debug=s', 'file=s',
    );

if ($opts->{help}) {
  usage();
  exit 0;
}

$$opts{db_name} = 'point-one' if ! $$opts{db_name};
$$opts{db_user} = 'point-one' if ! $$opts{db_user};
$$opts{db_pass} = 'point-one' if ! $$opts{db_pass};
$$opts{db_host} = 'database.internal.point-one.com' if ! $$opts{db_host};
$$opts{db_port} = 5432 if ! $$opts{db_port};

unless ($opts->{db_name}) {
    print STDERR "$program: missing required --db_name parameter\n";
    exit 1;
}
unless ($opts->{db_user}) {
    print STDERR "$program: missing required --db_user parameter\n";
    exit 1;
}
unless ($opts->{db_pass}) {
    print STDERR "$program: missing required --db_pass parameter\n";
    exit 1;
}

$openprint::dbh = sql::open_sql( $log,
    host      => $opts->{db_host},
    database  => $opts->{db_name},
    driver    => 'Pg',
    login     => $opts->{db_user},
    password  => $opts->{db_pass},
    port      => $opts->{db_port},
);
die "Error opening db at $$opts{db_user}:$$opts{db_pass} @ $$opts{db_host}:$$opts{db_port}" if ! $dbh;

if ( ! $$opts{file} and @ARGV ) {
  $$opts{file} = shift @ARGV;
}
require openprint::Company;
require openprint::User;

my $csv = Text::CSV_XS->new();
open ( FH, $$opts{file} ) or die "Can't open $$opts{file} : $!";
my @Companies = openprint::Company->find();
my %Companies = map { $_->name() => $_ } @Companies;
#my %Companies2 = map { $_->business_name() ? ( $_->business_name() => $_ ) : () } @Companies;

my %fields = (
ContactName => 'name',
AccountNumber => undef,
EmailAddress => 'email',
FirstName => 'firstname',
LastName  => 'lastname',
POAttentionTo => undef,
POAddressLine1 => undef,
POAddressLine2 => undef,
POAddressLine3 => undef,
POAddressLine4 => undef,
POCity          => undef,
PORegion        => undef,
POZipCode       => undef,
POCountry       => undef,
SAAttentionTo   => undef,
SAAddressLine1  => undef,
SAAddressLine2  =>  undef,
SAAddressLine3  =>  undef,
SAAddressLine4  =>  undef,
SACity          => undef,
SARegion        =>  undef,
SAZipCode       =>  undef,
SACountry       =>  undef,
PhoneNumber     =>  'phone',
FaxNumber       =>  undef,
MobileNumber    =>  undef,
DDINumber     =>  undef,
SkypeName     =>  undef,
BankAccountName   =>  undef,
BankAccountNumber =>  undef,
BankAccountParticulars  => undef,
TaxNumberType     =>  undef,
TaxNumber         =>  undef,
AccountsReceivableTaxCodeName   => undef,
AccountsPayableTaxCodeName      =>  undef,
Website           =>  undef,
LegalName         => undef,
Discount          =>  undef,
CompanyNumber     =>  undef,
DueDateBillDay    =>  undef,
DueDateBillTerm   =>  undef,
DueDateSalesDay   =>  undef,
DeDateSalesTerm   =>  undef,
SalesAccount      =>  undef,
PurchasesAccount  =>  undef,
TrackingName1     =>  undef,
SalesTrackingOption1 => undef,
PurchasesTrackingOption1  => undef,
TrackingName2     => undef,
SalesTrackingOption2 =>   undef,
PurchasesTrackingOption2  => undef,
BrandingTheme             =>  undef,
DefaultTaxBills           =>  undef,
DefaultTaxSales           =>  undef,
Person1FirstName          =>  undef,
Person1LastName           =>  undef,
Person1Email              =>  undef,
Person1IncludeInEmail     =>  undef,
Person2FirstName          =>  undef,
Person2LastName           =>  undef,
Person2Email              =>  undef,
Person2IncludeInEmail     =>  undef,
Person3FirstName          =>  undef,
Person3LastName           =>  undef,
Person3Email              =>  undef,
Person3IncludeInEmail     =>  undef,
Person4FirstName          =>  undef,
Person4LastName           =>  undef,
Person4Email              =>  undef,
Person4IncludeInEmail     =>  undef,
Person5FirstName          =>  undef,
Person5LastName           =>  undef,
Person5Email              =>  undef,
Person5IncludeInEmail     =>  undef,
);

my @fields;

while ( <FH> ) {
	my $status = $csv->parse($_);
  my @row = misc::trim($csv->fields());
  print scalar(@row) . " fields " . scalar(keys %fields) . " in fields\n";
  if ($row[0] eq '*ContactName') {
    $row[0] =~ s/\*//g;
    @fields = @row;
    print "Fields: @fields\n";
    next;
  } else {
    print "Rows: @row\n";
  }
	my %row;
  @row{@fields} = @row;
    
  if ( $row{ContactName} =~ /\(([^\)]+)\)/ ) {
    print "Have email in contact name ($1)\n";
    if ( !$row{EmailAddress} or ($row{EmailAddress} eq $1) ) {
      $row{EmailAddress} = $1;
      $row{ContactName} =~ s/\s*\($1\)\s*//g;
    }
  }
  if ( $row{ContactName} =~ /\// ) {
    my ( $name, $crap ) = split(/\//, $row{ContactName});
    print "Removing duplicate ";
    $row{ContactName} = $name;
    print $row{ContactName} . "\n";
  }

  my @names = split(/ /, $row{ContactName});
  if ((@names == 2) and ( !$row{FirstName} and !$row{LastName}) ) {
    $row{FirstName} = $names[0];
    $row{LastName} = $names[1];
  }

  $row{ContactName} = openprint::Company->transform(name=>$row{ContactName});

  my %data = map { defined($fields{$_}) ? ($fields{$_}=>$row{$_}) : () } keys %row;
	my $Company = $Companies{$row{ContactName}};

	if (!$Company) {
    if (!confirm("Have ContactName = $row{ContactName}, email = $row{EmailAddress} continue?")) {
      exit(0);
    }
    $Company = new openprint::Company();
    $Company->save(\%data);
    $Companies{$Company->name()} = $Company;
	} # end if
  $data{company_id} = $Company->id();

  if ( $data{email} ) {
    my $User = openprint::User->find_one(email=>$data{email}) if $data{email};
    if ( $User ) {
      if ($User->company_id() != $Company->id()) {
        print "User $$User{email} is not in this company $$Company{name} $$User{company_id} != $$Company{id}\n";
      }
      if (!confirm('User exists, continue?') ) {
        next;
      }
    }
    $User = new openprint::User() if !$User;

    $User->save(\%data);
  }
} # end while
close (FH);

$dbh->disconnect();

sub usage {
	print <<EOH;

usage: acc.pl [--help] 

The purpose of this script is to output the text files for importing into Hagen OA

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

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
