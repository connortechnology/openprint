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
    'host'      => $opts->{'db_host'},
    'database'  => $opts->{'db_name'},
    'driver'    => 'Pg',
    'login'     => $opts->{'db_user'},
    'password'  => $opts->{'db_pass'},
);
die 'Error opening db' if ! $dbh;

require openprint::Company;

my $csv = Text::CSV_XS->new();
open ( FH, "$$opts{file}" ) or die "Can't open $$opts{file} : $!";
my @Companies = openprint::Company->find();
my %Companies = map { $_->name(), $_ } @Companies;
my %Companies2 = map { $_->business_name(), $_ } @Companies;
while ( <FH> ) {
	my $status = $csv->parse($_);
	my ($acc_num, $name ) = misc::trim($csv->fields());
	next if ! $name;
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
		$log->warn("Company not found: $name : $acc_num");
		my $input = <STDIN>;
		last if $input eq 'q';
		next;
	} 
	
	if ( $$Company{accountnumber} eq $acc_num ) {
		$log->debug( "Company $name already has account # $acc_num" );
		next;
	}
	$_ = $Company->save( { accountnumber=>$acc_num } );
	if ( $_ ) {
		my $input = <STDIN>;
		last if $input eq 'q';
	} 
	$log->debug("Update $name to $acc_num");
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
