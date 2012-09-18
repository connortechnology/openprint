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
    'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','record=s', 'command=s', 'debug=s','addr=s',
);

if ($opts->{help}) {
    usage();
    exit 0;
}

# Get our configuration information
#if (my $err = ReadCfg('/etc/iq.conf')) {
    #die $err;
#}

foreach my $param ( 'db_name','db_user','db_pass' ) {
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
		'host'		=> $CFG::Config{'db_host'},
		'database'	=> $CFG::Config{'db_name'},
		'driver'	=> 'Pg',
		'login'		=> $CFG::Config{'db_user'},
		'password'	=> $CFG::Config{'db_pass'},
		);
if ( ! $dbh ) {
	die "Error opening db. $!";
} # end if

if ( $$opts{command} eq 'add' ) {
	my ( $host, $domain ) = $$opts{record} =~ /^([^\.])+\.(.+)$/;
	my ( $domain_id ) = sql::execute(undef,undef,'SELECT id FROM domains WHERE name=?', $domain );
	die "No domain_id found for $$opts{record}\n" if ! $domain_id;

	sql::execute( undef, undef, 'DELETE FROM records WHERE name=? AND content=? AND type=?', $$opts{record}, $$opts{addr}, 'A' );
	sql::insert( undef, undef, 'records', 'name'=>$$opts{record}, content=>$$opts{addr}, type=>'A','change_date'=>time,
		'domain_id'	=>$domain_id,
		ttl		=>	600,
		);
} elsif ( $$opts{command} eq 'remove' ) {
	sql::execute( undef, undef, 'DELETE FROM records WHERE name=? AND content=? AND type=?', $$opts{record}, $$opts{addr}, 'A' );
} # end if

$dbh->disconnect() if $dbh;
exit 0;

sub usage {
	print <<EOH;

usage: update_pdns [--help] 

The purpose of this script is to monitor hosts for uptime

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

1;
__END__
