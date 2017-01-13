#!/usr/bin/perl
use lib '/var/www/testing/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Company;
require openprint::User;
require openprint::Project;
require openprint::Quote;
require openprint::Order;

use openprint ();
use vars qw( $log $dbh %session );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*session = \%openprint::session;
#@session{'company_id','user_id'} = ( 6, 1085 );

$log = new logger( 'warn' );

$openprint::Object::no_cache = 1;
$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2], 'host'=>$ARGV[3]) );
	
foreach ( openprint::Skid->find( ) ) {
	$_->destroy();
} # end foreach Product
foreach ( openprint::Quote->find( ) ) {
	$_->destroy();
} # end foreach Product
foreach ( openprint::Order->find( ) ) {
	$_->destroy();
} # end foreach Product
foreach my $Project ( openprint::Project->find( ) ) {
	$Project->destroy();
} # end foreach Product
foreach ( openprint::User->find( 'deleted'=>[0,1]) ) {
	$_->destroy();
} # end foreach Product
foreach ( openprint::Company->find( 'deleted'=>[0,1] ) ) {
	$_->destroy();
} # end foreach Product
$dbh->do(q`SELECT setval('companies_id_seq',1);`);
$dbh->do(q`SELECT setval('users_id_seq',1);`);
my $Company = new openprint::Company();
$Company->save({
	'name'=>'ConnorTechnology',
	'business_name'=>'ConnorTechnology',
	'address1'	=>	'60 Wolfrey Ave',
	'city'		=>	'Toronto',
	'country'	=>	'CA',
	'state'		=>	'ON',
	'phone'		=>	'647-883-5483',
	'postalcode'	=>	'M4K1K8',
	'activation'	=>	'Y',
});
my $User = new openprint::User();
$User->save({
	'company_id'	=>	$Company->id(),
	'firstname'		=>	'Isaac',
	'lastname'		=>	'Connor',
	'email'			=>	'iconnor@connortechnology.com',
	'password'		=>	'XV35me',
	'type'		=>	'A',
	'web_active'	=>	'Y',
	'ftp_active'	=>	'Y',
});
my $Company = new openprint::Company();
$Company->save({
	'name'=>'Jonarts Imprimerie',
	'business_name'=>'Jonarts Imprimerie',
	'address1'	=>	'9010 Avenue du Parc',
	'city'		=>	'Montreal',
	'country'	=>	'CA',
	'state'		=>	'QC',
	'phone'		=>	'1.514.738.8224',
	'fax'		=>	'1.514.738.6054',
	'postalcode'	=>	'H2N 1Y8',
	'activation'	=>	'Y',
});
my $User = new openprint::User();
$User->save({
	'company_id'	=>	$Company->id(),
	'firstname'		=>	'Aris',
	'lastname'		=>	'Tsamalidis',
	'email'			=>	'info@jonarts.com',
	'password'		=>	'XV35me',
	'type'		=>	'A',
	'extension'		=>	'123',
	'web_active'	=>	'Y',
	'ftp_active'	=>	'Y',
});
$dbh->disconnect();
1;
__END__
