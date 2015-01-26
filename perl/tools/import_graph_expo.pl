#!/usr/bin/perl
use strict;
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
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s', 'debug=s', 'file=s',
 );

if ($opts->{help}) {
    usage();
    exit 0;
}

$$opts{db_name} = 'point-one' if ! $$opts{db_name};
$$opts{db_user} = 'point-one' if ! $$opts{db_user};
$$opts{db_pass} = 'point-one' if ! $$opts{db_pass};
$$opts{db_host} = 'database.internal.point-one.com' if ! $$opts{db_host};

foreach my $opt ( 'db_name','db_user','db_pass','file' ) {
unless ($opts->{$opt}) {
    print STDERR "$program: missing required --$opt parameter\n";
    exit 1;
}
}
$dbh = sql::open_sql( $log,
    'host'      => $opts->{'db_host'},
    'database'  => $opts->{'db_name'},
    'driver'    => 'Pg',
    'login'     => $opts->{'db_user'},
    'password'  => $opts->{'db_pass'},
);
die 'Error opening db' if ! $dbh;

require openprint::Company;
require openprint::Company_in_Marketing_Category;
require openprint::User;
require openprint::User_in_Marketing_Category;
require openprint::MarketingCategory;

my $Category = openprint::MarketingCategory->find_one(name=>'Graph Expo Attendees');
if ( ! $Category ) {
	$Category = new openprint::MarketingCategory();
	$Category->save({name=>'Graph Expo Attendees'});
} # end if

my $csv = Text::CSV_XS->new();
open ( FH, "$$opts{file}" ) or die "Can't open $$opts{file} : $!";
my @Companies = openprint::Company->find();
my %Companies = map { $_->name(), $_ } @Companies;
my %Companies2 = map { $_->business_name(), $_ } @Companies;
$log->warn("Finished loading companies");

my @Users = openprint::User->find();
my %Users = map { $_->email(), $_ } @Users;
$log->warn("Finished loading users");

my $ac = sql::start_transaction( $dbh );

while ( <FH> ) {
	my $status = $csv->parse($_);
	my ($first, $middle, $last, $company_name, $title, $address, $city, $state, $zip, $country, $phone, $url, $email, $revenue, $employees, $type ) = misc::trim($csv->fields());
	next if $first eq 'First Name';
	next if ! $company_name;
$log->debug("Doing $company_name");
	my $name = openprint::Company->transform(name=>$company_name);

	my $Company = $Companies{$name};
	$Company = $Companies2{$name} if ! $Company;

	if ( ! $Company ) {
		$name =~ /(.+)\.$/;
		if ( $1 and ( $1 ne $name ) ) {
			$name = $1;
			$Company = $Companies{$name};
		} # end if
	} # end if
	if ( ! $Company ) {
		$name =~ /(.*) inc$/i;
		if ( $1 and ( $1 ne $name ) ) {
			$name = $1;
			$Company = $Companies{$name};
		} # end if
	} # end if
	if ( ! $Company ) {
		$name =~ s/\s+/ /g;
		$Company = $Companies{$name};
	} # end if
	if ( ! $Company ) {
$log->warn("Adding company: $name");
		$Company = new openprint::Company();
		$_ = $Company->save({
			name=>$name,
			business_name	=>	$company_name,
			address1	=>	$address,
			state	=>	$state,
			country	=>	$country,
			city	=>	$city,
			postalcode	=>	$zip,
			phone	=>	$phone,
			business_type	=>	$type,
			});
		die $_ if $_;
		$Companies{$name} = $Company;
		my $CiMC = new openprint::Company_in_Marketing_Category();
		$_ = $CiMC->save({ company_id=>$Company->id(), category_id=>$Category->id() });
		die $_ if $_;
	} else {
if ( 0 ) {
		my %updates = (
				( $Company->address1() ? () : ( address1 => $address )),
				( $Company->state() ? () : ( state => $state )),
				( $Company->country() ? () : ( country => $country )),
				( $Company->city() ? () : ( city => $city )),
				( $Company->postalcode() ? () : ( postalcode => $zip )),
				( $Company->phone() ? () : ( phone => $phone )),
				( $Company->business_type() ? () : ( business_type => $type )),
				);	

		if ( %updates ) {
			$_ = $Company->save(\%updates);
			die $_ if $_;
			$log->warn("Updating company: $name " . join(",", map { $_ .'=>'. $updates{$_} } keys %updates ) );
		} else {
			$log->warn("Not Updating company: $name");
		} # end if
}

		my $CiMC = openprint::Company_in_Marketing_Category->find( company_id=>$Company->id(), category_id=>$Category->id() );
		if ( ! $CiMC ) {
			$CiMC = new openprint::Company_in_Marketing_Category();
			$_ = $CiMC->save({ company_id=>$Company->id(), category_id=>$Category->id() });
			die $_ if $_;
		} # end if
	} # end if

	my $Profile = $Company->Profile();

		if ( ! $Profile->url() ) { 
			$Profile->value( url => $url );
		}
		if ( ! $Profile->employees() ) {
			$Profile->value( employees => $employees );
		} 
		if ( ! $Profile->annual_sales() ) {
			$Profile->value( annual_sales => $revenue );
		} 
	

	my $User = $Users{$email};
	if ( ! $User ) {
		$User = new openprint::User();
		$_ = $User->save({
			firstname	=>	$first,
			lastname	=>	$last,
			title		=>	$title,
			email		=>	$email,
			phone		=>	$phone
		});
		die $_ if $_;
		$log->warn("Adding user $first $last $email to $name");
		my $UiMC = new openprint::User_in_Marketing_Category();
		$_ = $UiMC->save({ user_id=>$User->id(), category_id=>$Category->id() });
		die $_ if $_;
	} else {
		if ( ! $$User{company_id} ) {
			$User->save({company_id=>$Company->id() });
		} elsif ( $User->company_id() != $Company->id() ) {
			my $C = $User->Company();
			$log->warn("User $email is in the wrong company? $$C{name} != $$Company{name}");
$log->debug(" Company: " . $Company->to_string() );
		} 
		my $UiMC = openprint::User_in_Marketing_Category->find( user_id=>$User->id(), category_id=>$Category->id() );
		if ( ! $UiMC ) {
			$UiMC = new openprint::User_in_Marketing_Category();
			$_ = $UiMC->save({ user_id=>$User->id(), category_id=>$Category->id() });
			die $_ if $_;
		} # end if
	}
	
	#last;
} # end while
close (FH);

#$dbh->rollback();
sql::end_transaction( $dbh, $ac );

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
