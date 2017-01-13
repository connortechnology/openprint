#!/usr/bin/perl -w
use strict;
use lib '/var/www/testing/perl';

require sql;
require misc;
require logger;

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

require openprint::User;
require Email::Valid;

foreach my $User ( openprint::User->find( email_valid => undef ) ) {
	my $valid = Email::Valid->address( $User->email() );
	if ( defined $valid ) {
	sql::update( undef, undef, 'users', ['id=?', $$User{id}], email_valid => 1 );
	}
}

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
