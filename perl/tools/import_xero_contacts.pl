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
$log = logger->new();
$log->{level} = 'debug';

use Getopt::Long;
use File::Basename qw(basename);

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help',
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s', 'db_port=s', 'debug=s', 'file=s',
 );

if ($opts->{help}) {
    usage();
    exit 0;
}

$$opts{db_name} = 'point-one' if ! $$opts{db_name};
$$opts{db_user} = 'point-one' if ! $$opts{db_user};
$$opts{db_pass} = 'point-one' if ! $$opts{db_pass};
$$opts{db_host} = 'database.internal.point-one.com' if ! $$opts{db_host};

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

$dbh = sql::open_sql( $log,
    host      => $opts->{db_host},
    database  => $opts->{db_name},
    driver    => 'Pg',
    login     => $opts->{db_user},
    password  => $opts->{db_pass},
    port      =>  $opts->{db_port},
);
die 'Error opening db' if ! $dbh;

if ( ! $$opts{file} and @ARGV ) {
  $$opts{file} = shift @ARGV;
}
require openprint::Company;
require openprint::User;

my $csv = Text::CSV_XS->new();
open ( FH, $$opts{file} ) or die "Can't open $$opts{file} : $!";
my @Companies = openprint::Company->find();
my %Companies = map { $_->name(), $_ } @Companies;
my %Companies2 = map { $_->business_name(), $_ } @Companies;

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
PORegion        => undef
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
PhoneNumber     =>  undef,
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
DeDateSalesTerm,SalesAccount,PurchasesAccount,TrackingName1,SalesTrackingOption1,PurchasesT
rackingOption1,TrackingName2,SalesTrackingOption2,PurchasesTrackingOption2,BrandingTheme,DefaultTaxBills,DefaultTaxSales,Person1FirstName,Person1LastName,Person1Em
ail,Person1IncludeInEmail,Person2FirstName,Person2LastName,Person2Email,Person2IncludeInEmail,Person3FirstName,Person3LastName,Person3Email,Person3IncludeInEmail,P
erson4FirstName,Person4LastName,Person4Email,Person4IncludeInEmail,Person5FirstName,Person5LastName,Person5Email,Person5IncludeInEmail

);

while ( <FH> ) {
	my $status = $csv->parse($_);
	my ($name, $email ) = misc::trim($csv->fields());
	next if ! $name;

	my $Company = $Companies{$name};

	if ( ! $Company ) {
    $Company = new openprint::Company();
    $Company->save({name=>$name});
	} # end if
  my ( $first, $last ) = split(' ', $name );
  my $User = new openprint::User( );
  $User->save({ firstname=>$first, lastname=>$last, email=>$email, company_id=>$Company->id() });
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

1;
__END__
