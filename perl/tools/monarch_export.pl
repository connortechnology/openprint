#!/usr/bin/perl
use strict;
use lib '/var/www/testing/perl';

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

my @tables = ( 'Customer', 'Supplier', 'Employee', 'Cust_Contacts', 'Job', 'Items' );

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help',
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','table=s', 'debug=s', 'version=s',
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

$$opts{version} = '13.1' if ! $$opts{version};
$$opts{table_path} = 'Monarch' if ! $$opts{table_path};

$dbh = sql::open_sql( $log,
    'host'      => $opts->{'db_host'},
    'database'  => $opts->{'db_name'},
    'driver'    => 'Pg',
    'login'     => $opts->{'db_user'},
    'password'  => $opts->{'db_pass'},
);
die 'Error opening db' if ! $dbh;

require openprint::Company;
require openprint::User;
require openprint::Project;
my %tables = (
'Customer'	=>	{ object => 'Company', find=>[ order=>'name', ( $$opts{limit} ? ( limit => $$opts{limit} ) : () ), supplier=>'N' ] },
'Supplier'	=>	{ object => 'Company', find=>[ order=>'name', ( $$opts{limit} ? ( limit => $$opts{limit} ) : () ), supplier=>'Y' ] },
'Employee'	=>	{ object => 'User', find=>[ order=>'firstname,lastname', ( $$opts{limit} ? ( limit => $$opts{limit} ) : () ), 'type in'=>['E','A'] ] },
'Cust_Contacts'	=>	{ object => 'User', find=>[ order=>'firstname,lastname', ( $$opts{limit} ? ( limit => $$opts{limit} ) : () ), type=>'C', email_valid=>1 ] },
'Job'		=>	{ object => 'Project', find=>[ order=>'id', ( $$opts{limit} ? ( limit => $$opts{limit} ) : () ), 'order_id is null'=>0 ] },
'Items-Paper'		=>	{ object => 'Paper', find=>[ order=>'id', ( $$opts{limit} ? ( limit => $$opts{limit} ) : () ), 'in_stock >'=>0 ] },
'Items-Materials'	=>	{ object => 'Materials', find=>[ order=>'id', ( $$opts{limit} ? ( limit => $$opts{limit} ) : () ) ] },
);
foreach my $table ( $$opts{table} ? split(',',$$opts{table} ) : @tables ) {
	my %fields;
	my @fields;
	my $csv = Text::CSV_XS->new();
	open ( FH, "$$opts{table_path}/$$opts{version}/$table.csv" ) or die "Can't open $$opts{table_path}/$$opts{version}/$table.csv : $!";
	$_ = <FH>; # DROP FEILD NAMES
	while ( <FH> ) {
		my $status = $csv->parse($_);
		my ($field, $iq_field, $type, $start, $size, $end, $desc, $validated, $required, $default, $notes ) = misc::trim($csv->fields());
		$fields{$field} = { size => $size, iq_field=>$iq_field, default=>$default };
		push @fields, $field;
	} # end while
	close (FH);

	open( FH, ">$table.txt" ) or die "Can't open $table.txt $!";
	foreach my $Object ( ('openprint::'.$tables{$table}{object})->find( @{$tables{$table}{find}} ) ) {
		my $format_string = join('', map { '%-'.$fields{$_}{size}.'s' } @fields ) . "\n";
		my @values;
		foreach my $field ( @fields ) {
			my $value = $fields{$field}{default};
			if ( my $iq_field = $fields{$field}->{iq_field} ) {
				$value = eval $iq_field;
				$log->error( "Eval error $@" ) if $@;
				$value = substr($value, 0,$fields{$field}{size});
			} # end if
			push @values, $value;
		}

		print FH sprintf( $format_string, @values );
	} # end foreach Cmompany
	close( FH );
} # end foreach

$dbh->disconnect();

sub usage {
	print <<EOH;

usage: monarch_export.pl [--help] 

The purpose of this script is to output the text files for importing into Hagen OA

Command-line options:

	--help		Displays this message.
    --db_name	
	--db_host
	--db_user
	--db_pass
	--table	One of @tables,
	--debug
	--version
	--limit		# of results

EOH
} # end sub usage

1;
__END__
