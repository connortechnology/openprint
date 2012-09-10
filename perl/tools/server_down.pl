#!/usr/bin/perl
use utf8;
use lib '/var/www/testing/perl';
use strict;
use LWP;

require configuration;
require sql;
require openprint::Host;
require logger;
require openprint::Log;

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
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','record=s', 'command=s', 'debug=s','addr=s', 'index=s', 'commit=s',
);

if ($opts->{help}) {
    usage();
    exit 0;
}

foreach my $param ( 'db_name','db_user','db_pass', 'addr' ) {
    $CFG::Config{$param} = $$opts{$param} if $$opts{$param};
    if ( ! $CFG::Config{$param} ) {
        die "$program: missing required --$param parameter";
    }
} # end foreach required-param

foreach my $param ( 'db_host', 'log_file', 'log_level' ) {
    $CFG::Config{$param} = $$opts{$param} if $$opts{$param};
} # end foreach non-required param

$CFG::Config{'log_level'} = 'debug' if ! $CFG::Config{'log_level'};
$log = logger->new( {'file'=>$CFG::Config{'log_file'}, 'level'=>$CFG::Config{'log_level'}} );

$log->debug("Connecting to db");
$dbh = sql::open_sql( $log,
        'host'      => $CFG::Config{'db_host'},
        'database'  => $CFG::Config{'db_name'},
        'driver'    => 'Pg',
        'login'     => $CFG::Config{'db_user'},
        'password'  => $CFG::Config{'db_pass'},
        );
if ( ! $dbh ) {
    die "Error opening db. $!";
} # end if


my $domains = $dbh->selectall_arrayref( 'SELECT * FROM domains', { Slice => {} } );

foreach my $domain ( @{$domains} ) {
	print "Updating $$domain{name}\n";

	foreach my $host ( 'www', 'mail', 'ftp' ) {
		my $name = $host.'.'.$$domain{name};
		my $records = $dbh->selectall_arrayref( 'SELECT * FROM records WHERE name=? AND type=?', {Slice => {}}, $name, 'A' );
		if ( ! $records ) {
			print "Error loading records\n";
			next;
		} 
		if ( ! @{$records} ) {
			print "No records found for $name\n";
			next;
		} # end if
		if ( @{$records} == 1 ) {
			if ( $$records[0]{addr} == $$opts{addr} ) {
				print "This addr is the last record for $name.  Not deleting it.\n";
				next;
			} # end if
		} # en dif
		if ( $$opts{commit} ) {
			$dbh->do( 'DELETE FROM records WHERE name=? AND content=? AND type=?', {}, $name, $$opts{addr}, 'A' );
		} else {
			print " Would delete $name\n";
		} # end if
	} # end foreach host

	my $soa = $dbh->selectrow_hashref( 'SELECT * FROM records WHERE name=? AND type=?', {}, $$domain{name}, 'SOA' );
	if ( $dbh->errstr() or ! $soa ) {
		$log->error("ERror finding SOA record.");
		print "\n";
		next;
	} # end if
	
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
	$year += 1900;
	$mon += 1;
	my $date_string = sprintf('%.4d%.2d%.2d', $year,$mon,$mday);


	my ( $ns, $email, $sn, $refresh, $retry, $expiry, $min ) = $$soa{content} =~ /\s*(\S+)\s+(\S+)\s+(\d+)\s+(\d*)\s+(\d*)\d+(\d*)\s+(\d*)\s*/;
	my ( $ns, $email, $sn, $refresh, $retry, $expiry, $min ) = split( /\s/, $$soa{content} );
	if ( $sn =~ /^$date_string/ ) {
		$sn += 1;
	} else {
		$sn = $date_string .'01';
	} # end if
	if ( $$opts{commit} ) {
		sql::update( undef, undef, 'records', [ 'name=? AND type=?', $$domain{name}, 'SOA' ], content=>"$ns $email $sn $refresh $retry $expiry $min" );
		print "Updating soa from ($$soa{content}) to ($ns $email $sn $refresh $retry $expiry $min)\n";
	} else {
		print "Would update soa from ($$soa{content}) to ($ns $email $sn $refresh $retry $expiry $min)\n";
	} # end if

	print "\n";

} # end foreach domain


$dbh->disconnect();

1;
__END__
