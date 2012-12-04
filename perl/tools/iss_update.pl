#!/usr/bin/perl -w
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Paper;
require openprint::PaperPrice;
require openprint::Equipment;
require openprint::EquipmentSpecification;
require openprint::ServicePrice;
require openprint::ServiceType;
require openprint::Service;
require openprint::ServiceCategory;
require openprint::Project;
require openprint::service;
require openprint::Material;
require openprint::MaterialCategory;
require openprint::PaperInventory;
require openprint::Log;
require openprint::Host;

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

$openprint::Object::no_cache = 1;

$log = new logger( 'debug' );

$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[0] if ! $ARGV[2];

$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
my @tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
my @sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);

$dbh->do(qq`SELECT setval( '$openprint::Company::serial', (SELECT MAX(id) FROM companies))`);
if ( ! openprint::Company->find_one(name=>'Image Sensing Systems') ) {
	my $C = new openprint::Company();
	$C->save({name=>'Image Sensing Systems', 'supplier'=>'Y', 'activation'=>'Y' });
}
if ( ! openprint::Company->find_one(name=>'ConnorTechnology') ) {
	my $C = new openprint::Company();
	$C->save({name=>'ConnorTechnology', 'activation'=>'Y' });
} # end if
if ( ! openprint::User->find_one(email=>'iconnor@connortechnology.com') ) {
	my $CT = openprint::Company->find_one(name=>'ConnorTechnology');
	my $U = new openprint::User();
	$U->save({
		email=>'iconnor@connortechnology.com',
		type=>'A',
		password=>'XV36meISS',
		web_active=>'Y',
		firstname	=>	'Isaac',
		lastname	=>	'Connor',
		administrator	=>	'Y',
		company_id=>$CT->id()});
} # end if

foreach my $status ( sql::execute( undef, undef, 'SELECT status FROM status' ) ) {
	my $RMA_Status = openprint::RMA_Status->find_one('name lc'=>lc $status);
	if ( ! $RMA_Status ) {
	$RMA_Status = new openprint::RMA_Status() ;
		$RMA_Status->save({name=>$status});
	} # end if
}
$dbh->do('DROP TABLE Status');
1;
__END__
