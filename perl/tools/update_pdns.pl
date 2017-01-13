#!/usr/bin/perl
use utf8;
use lib '/var/www/testing/perl';
use strict;
use LWP;
use Getopt::Long;
use File::Basename qw(basename);

require configuration;
require sql;
require openprint::Host;
require logger;
require openprint::Log;

use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;
$log = logger->new('debug');

my $program = basename($0);

my $opts = {};
GetOptions($opts, 'help', 
	'db_name=s', 'db_host=s', 'db_user=s', 'db_pass=s','record=s', 'command=s', 'debug=s','addr=s',
);

if ($opts->{help}) {
	usage();
	exit 0;
}

configuration::merge( $opts );
foreach my $param ( 'db_name','db_user','db_pass', 'command', 'addr' ) {
	die "$program: missing required --$param parameter" if ! $config{$param};
} # end foreach required-param

$config{log_level} = 'debug' if ! $config{log_level};
$log = logger->new( {file=>$config{log_file}, level=>$config{log_level}} );

$log->debug("Connecting to db");
$dbh = sql::open_sql( $log,
		host		=> $config{db_host},
		database	=> $config{db_name},
		driver		=> 'Pg',
		login		=> $config{db_user},
		password	=> $config{db_pass},
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

The purpose of this script is to add/remove/update reconds in DNS

Examples:
./update_pdns --command=add --addr=192.168.1.2 record=www.connortechnology.com
./update_pdns --command=remove --addr=192.168.1.2 record=www.connortechnology.com

Command-line options:

	--help		Displays this message.

EOH
} # end sub usage

1;
__END__
