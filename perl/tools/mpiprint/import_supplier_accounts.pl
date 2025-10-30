#!/usr/bin/perl
use strict;
use warnings;
use lib '/var/www/openprint/perl';

my $limit = 10;

require sql;
require misc;
require logger;
require states;

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
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s', 'db_port=s', 'debug=s', 'file=s', 'y',
 );

if ($opts->{help}) {
    usage();
    exit 0;
}

$$opts{db_name} = 'mpiprint' if ! $$opts{db_name};
$$opts{db_user} = 'mpiprint' if ! $$opts{db_user};
$$opts{db_pass} = 'mpiprint' if ! $$opts{db_pass};
#$$opts{db_host} = '' if ! $$opts{db_host};

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
    'host'      => $opts->{db_host},
    'database'  => $opts->{db_name},
    'driver'    => 'Pg',
    'login'     => $opts->{db_user},
    'password'  => $opts->{db_pass},
    'port'      =>  $opts->{db_port},
);
die 'Error opening db' if ! $dbh;

require openprint::Company;
require openprint::User;

my $csv = Text::CSV_XS->new();
open ( FH, "$$opts{file}" ) or die "Can't open $$opts{file} : $!";
my @Companies = openprint::Company->find();
my %Companies = map { $_->name()=> $_ } @Companies;
my %Companies2 = map { $_->business_name() ? ($_->business_name(), $_) : () } @Companies;


while ( <FH> ) {
	my $status = $csv->parse($_);
  #Customer,Contact First Name,Contact Last Name,Add. Line 1,City,State,Zip,Country
	my (undef, $name, $contact, $email, $phone,
    $address, $city, $state, $zip, $category
  ) = misc::trim($csv->fields());
	next if ! $name;
  next if $name eq 'Customer' or $name eq 'COMPANY NAME';

  my $company_name = join(' ', map { ucfirst(lc $_) } split(/\s+/, $name));
  my $business_name = $company_name;
  $company_name = openprint::Company->transform(name=>$company_name);

  my $extension;
  if ($phone =~ /([\d\-]+) ext (\d+)/) {
    $phone = $1;
    $extension = $2;
  }

  my $url;
  if (-1 == index($email, '@')) {
    $url = $email;
    $email = '';
  }

  my %changes = (name=>$company_name,
    supplier=>'Y',
          business_name => $business_name,
          address1=>$address,
          city=>$city,
          state=>$state,
          postalcode=>$zip,
          country=>$states::states{$state} ? 'US' : 'CA',
          phone=>$phone,
          ($url ? (url=>$url) : ()),
        );

	my $Company = $Companies{$company_name};

  if ( ! $Company ) {
    print "Company? $company_name $Companies{$company_name}\n";
    if (confirm("Create ($company_name) $address ?", 'Y')){
      $Company = new openprint::Company();
      $Company->save(\%changes);
    } else {
      %changes = (name=>$name,
        supplier=>'Y',
        business_name => $name,
        address1=>$address,
        city=>$city,
        state=>$state,
        postalcode=>$zip,
        country=>$states::states{$state} ? 'US' : 'CA',
        phone=>$phone,
        ($url ? (url=>$url) : ()),
      );
      if (confirm("How about ($name) $address ?", 'Y')){
        $Company = new openprint::Company();
        $Company->save(\%changes);
      } else {
        next;
      }

    }
  } else {
    print "Company $company_name already exists\n";
    $Company->deleted(0) if $Company->deleted();
    my @changes = $Company->changes(\%changes);
    if (@changes and confirm("Update $company_name : @changes")) {
      $Company->save(\%changes);
    }
	} # end if

  my ($firstname, $lastname) = $contact =~ /^(\w+)\s+(\w+)$/;
  $firstname = $contact if ! $firstname;
  $firstname = ucfirst(lc($firstname));
  $lastname = ucfirst(lc($lastname)) if $lastname;

  my $user = openprint::User->find_one(
    company_id=>$Company->id(),
    'firstname lc'=>lc openprint::User->transform(firstname=>$firstname),
    ($lastname ? ('lastname lc'=>lc openprint::User->transform(lastname=>$lastname)) : ()),
  );
  if (!$user)  {
    if (confirm("Add $firstname $lastname to $name")) {

      $user = new openprint::User( );
      $user->save({ firstname=>$firstname, lastname=>$lastname,
          email=>$email,
          company_id=>$Company->id(),
          phone => $phone,
          extension => $extension,
        });
    }
  } else {
    my @changes = $user->changes({ firstname=>$firstname, lastname=>$lastname,
        email=>$email,
        phone => $phone,
        extension => $extension,
      });
    if (@changes and confirm("Apply @changes?", 'Y')) {
      $user->save({ firstname=>$firstname, lastname=>$lastname,
        email=>$email,
        phone => $phone,
        extension => $extension,
      });
    }
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
  my $prompt = shift;
  my $default = @_ ? lc shift : 'y';
  print $prompt ? $prompt : "Confirm? (Y|n)";
  if ( $$opts{y} ) {
    print "Y\n";
    return 1;
  }
  if ( $$opts{n} ) {
    print "N\n";
    return 0;
  }
  $_=<STDIN>; chomp;
  return 1 if $_ and ( lc($_) eq 'y');
  return 1 if (!$_) and ($default eq 'y');
  return 0;
}

1;
__END__
