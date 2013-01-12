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
use Authen::Passphrase::BlowfishCrypt;

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
$dbh->do('ALTER TABLE Fault_Found rename to Faults_Found');
$dbh->do('ALTER TABLE RMA DROP COLUMN Comments');
$dbh->do('ALTER TABLE RMA DROP COLUMN winvoice');
$dbh->do('ALTER TABLE Parts RENAME to RMA_Parts');
$dbh->do('ALTER TABLE RMA_Parts rename column qty to quantity');
$dbh->do('ALTER TABLE RMA_Parts DROP scrap');
$dbh->do('ALTER TABLE RMA_Parts DROP testid');
$dbh->do('ALTER TABLE RMA_Parts DROP subtotal');
$dbh->do('ALTER TABLE RMA_Parts DROP serialscrap');
$dbh->do('ALTER SEQUENCE Parts_id_seq RENAME to RMA_Parts_id_seq');
$dbh->do(q`ALTER TABLE RMA_Parts ALTER id SET DEFAULT nextval('rma_parts_id_seq')`);
$dbh->do(q`SELECT setval('rma_parts_id_seq', ( SELECT MAX(id) FROM rma_parts ) )`);
$dbh->do('DROP TABLE rs232form');
$dbh->do('DROP TABLE switchboard_items');
$dbh->do('DROP TABLE switchboard_items1');
$dbh->do('ALTER TABLE Units RENAME TO Products');
$dbh->do('ALTER Table Products rename column unitname to name');
$dbh->do('ALTER Table Products DROP version');
$dbh->do('ALTER Table Products DROP vendor');
$dbh->do('ALTER table products drop constraint  "units_pkey"');
$dbh->do('ALTER TABLE RMA DROP partsid');
$dbh->do('ALTER TABLE RMA DROP packingslipno');
$dbh->do('ALTER TABLE RMA DROP time_spent');
$dbh->do('ALTER TABLE RMA DROP area_of_defect');



`./db_update.pl $ARGV[0]  $ARGV[1] $ARGV[2]` or die $!;
`./db_update2.pl $ARGV[0]  $ARGV[1] $ARGV[2]` or die $!;
#`./load_locations.pl $ARGV[0]  $ARGV[1] $ARGV[2]` or die $!;
`./db_update3.pl $ARGV[0]  $ARGV[1] $ARGV[2]` or die $!;
my @tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
my @sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);
configuration::init( { db_name => $ARGV[0], db_host=>$ARGV[3], db_user=>$ARGV[1] } );

$dbh->do(qq`SELECT setval( '$openprint::Company::serial', (SELECT MAX(id) FROM companies))`);
my $ISS;
if ( ! ( $ISS = openprint::Company->find_one(name=>'Image Sensing Systems') ) ) {
	$ISS = new openprint::Company();
	$_ = $ISS->save({name=>'Image Sensing Systems', 'supplier'=>'Y', 'activation'=>'Y' });
	die $_ if $_;
}
if ( ! openprint::User->find_one(email=>'nsilver@imagesensingca.com') ) {
	my $password = 'rma';
	if ( $config{encrypt_passwords} ) {
		my $ppr = Authen::Passphrase::BlowfishCrypt->new(
				cost => 8,
				salt_random=>1,
				passphrase =>$password );
		$password= $ppr->as_rfc2307;
	} # end if

	my $U = new openprint::User();
	$_ = $U->save({
		email=>'nsilver@imagesensingca.com',
		type=>'A',
		password=>$password,
		web_active=>'Y',
		firstname   =>  'Nathan',
		lastname    =>  'Silver',
		administrator   =>  'Y',
		company_id=>$ISS->id()});
	die $_ if $_;
} # end if

my $Econolite;
if ( ! ( $Econolite = openprint::Company->find_one(name=>'Econolite') ) ) {
    $Econolite = new openprint::Company();
    $_ = $Econolite->save({name=>'Econolite', 'supplier'=>'Y', 'activation'=>'Y' });
    die $_ if $_;
}
if ( ! openprint::User->find_one(email=>'econolite@imagesensingca.com') ) {
	my $password = 'rma';
	if ( $config{encrypt_passwords} ) {
		my $ppr = Authen::Passphrase::BlowfishCrypt->new(
				cost => 8,
				salt_random=>1,
				passphrase =>$password );
		$password= $ppr->as_rfc2307;
	} # end if

	my $U = new openprint::User();
	$_ = $U->save({
		email=>'econolite@imagesensingca.com',
		type=>'E',
		password=>$password,
		web_active=>'Y',
		firstname   =>  'Nathan',
		lastname    =>  'Silver',
		administrator   =>  'Y',
		company_id=>$Econolite->id()});
	die $_ if $_;
} # end if

my $CT;
if ( ! ( $CT = openprint::Company->find_one(name=>'ConnorTechnology') ) ) {
	$CT = new openprint::Company();
	$_ = $CT->save({name=>'ConnorTechnology', 'activation'=>'Y' });
	die $_ if $_;
} # end if
if ( ! openprint::User->find_one(email=>'iconnor@connortechnology.com') ) {
	my $password = 'XV36meISS';
	if ( $config{encrypt_passwords} ) {
		my $ppr = Authen::Passphrase::BlowfishCrypt->new(
				cost => 8,
				salt_random=>1,
				passphrase =>$password );
		$password= $ppr->as_rfc2307;
	} # end if
	my $U = new openprint::User();
	$_ = $U->save({
		email=>'iconnor@connortechnology.com',
		type=>'A',
		password=>$password,
		web_active=>'Y',
		firstname	=>	'Isaac',
		lastname	=>	'Connor',
		administrator	=>	'Y',
		company_id=>$CT->id()});
	die $_ if $_;
} # end if

if ( 0 ) {
	foreach my $status ( sql::execute( undef, undef, 'SELECT status FROM status' ) ) {
		my $RMA_Status = openprint::RMA_Status->find_one('name lc'=>lc $status);
		if ( ! $RMA_Status ) {
		$RMA_Status = new openprint::RMA_Status() ;
			$RMA_Status->save({name=>$status});
		} # end if
	}
	$dbh->do('DROP TABLE Status');
} else {
	$dbh->do('ALTER TABLE RMA_Statuses RENAME COLUMN status to name');
} # end if
`./encrypt_passwords.pl $ARGV[0] localhost $ARGV[1] $ARGV[2]`;
$dbh->do(q`update addresses set country='Turkey', city='Istanbul' where city='Istanbul, Turkey';`);
`./convert_addresses.pl	$ARGV[0] $ARGV[1] $ARGV[2]`;
$dbh->do('UPDATE RMA SET shipto_address_id=(SELECT id FROM addresses WHERE addresses.company_id=rma.company_id)');
$dbh->do(q`UPDATE Companies Set country='US' WHERE country='USA'`);
$dbh->do(q`UPDATE Companies Set country='CA' WHERE country='CANADA'`);
$dbh->do(q`INSERT INTO tests (name) values ('Window Test')`);
$dbh->do('UPDATE test_results set test_id=1');
$dbh->do(q`update configuration set value='2009' where name='startYear';`);
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='orders'", 'column_name');
$dbh->do('ALTER TABLE Orders DROP vendor') if exists $$data{vendor};
$dbh->do('ALTER TABLE Orders DROP openbalance') if exists $$data{openbalance};
$dbh->do('ALTER TABLE Orders DROP shippingmethodid') if exists $$data{openbalance};
$dbh->do('DROP TABLE employee') if sets::isin('employee', \@tables );
$dbh->do('DROP TABLE Parts_slip') if sets::isin('parts_slip', \@tables );
$dbh->do('DROP TABLE Parts_slip_details') if sets::isin('parts_slip_details', \@tables );
$dbh->do('DROP TABLE scrap') if sets::isin('scrap', \@tables );
my $Shipping_Category;
if ( ! ( $Shipping_Category = openprint::ServiceType_Category->find_one(name=>'Shipping')  ) ) {
	$Shipping_Category = new openprint::ServiceType_Category();
	$_ = $Shipping_Category->save({name=>'Shipping'});
	die $_ if $_;
} # end if
if ( sets::isin( 'shippingby', \@tables ) ) {
	foreach my $shipby ( sql::execute(undef,undef,'SELECT shippingname from shippingby')){
		next if openprint::ServiceType->find_one(name=>$shipby);
		my $SType = new openprint::ServiceType();
		$_ = $SType->save({name=>$shipby,category_id=>$Shipping_Category->id()});	
		die $_ if $_;
	} # end foreach
	$dbh->do('DROP TABLE shippingby');
} # end if
my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='rma'", 'column_name');
$dbh->do('ALTER TABLE RMA drop shippername') if exists $$data{shippername};
$dbh->do('ALTER TABLE RMA drop environmental_test') if exists $$data{environmental_test};
$dbh->do('ALTER TABLE RMA drop new_coefficient') if exists $$data{new_coefficient};
$dbh->do('ALTER TABLE RMA drop bias') if exists $$data{bias};
$dbh->do('ALTER TABLE RMA drop shippername') if exists $$data{shippername};
$dbh->do('DROP TABLE name_autocorrect_save_failures');
$dbh->do('DROP TABLE supplies');

1;
__END__
