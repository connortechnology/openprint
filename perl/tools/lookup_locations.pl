#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Location;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;

$log = new logger( 'debug' );

$openprint::Object::no_cache = 1;
$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[1] if ! $ARGV[2];
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
die if ! $dbh;

foreach my $L ( openprint::Location->find('latitude is null'=>1) ) {
	my ( $lat, $long ) = $L->get_latitude_and_longitude();
	$L->save() if $lat;
} # end foreach $L

$dbh->disconnect();
1;
__END__
