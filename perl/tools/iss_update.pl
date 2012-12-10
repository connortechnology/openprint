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
if ( ! openprint::Company->find_one(name=>'Image Sensing Systems') ) {
	my $C = new openprint::Company();
	$_ = $C->save({name=>'Image Sensing Systems', 'supplier'=>'Y', 'activation'=>'Y' });
	die $_ if $_;
}
if ( ! openprint::User->find_one(email=>'nsilver@imagesensingca.com') ) {
    my $CT = openprint::Company->find_one(name=>'Image Sensing Systems');
    if ( $CT ) {
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
            company_id=>$CT->id()});
        die $_ if $_;
    } # end if
} # end if

my $Econolite;
if ( ! $Econolite = openprint::Company->find_one(name=>'Econolite') ) {
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
} # end if

if ( ! openprint::Company->find_one(name=>'ConnorTechnology') ) {
	my $C = new openprint::Company();
	$_ = $C->save({name=>'ConnorTechnology', 'activation'=>'Y' });
	die $_ if $_;
} # end if
if ( ! openprint::User->find_one(email=>'iconnor@connortechnology.com') ) {
	my $CT = openprint::Company->find_one(name=>'ConnorTechnology');
	if ( $CT ) {
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
$dbh->do(q`UPDATE Companies Set country='US' WHERE country='USA'`);
$dbh->do(q`UPDATE Companies Set country='CA' WHERE country='CANADA'`);
$dbh->do(q`INSERT INTO tests (name) values ('Window Test')`);
$dbh->do('UPDATE test_results set test_id=1');
$dbh->do(q`update configuration set value='2009' where name='startYear';`);
1;
__END__
