#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Paper;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );

$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2]) );
my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
print "Current Database Version: $version Backups: $backup, Last Updated: $updated_on\n";
if ( $version < 1275 ) {
	print "Updating to version 1275\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('alter table papers add bladecleaning boolean');
	sql::update( undef, undef, 'papers', 'bladecleaning IS NULL', 'bladecleaning', 'false' );
	sql::insert( undef, undef, 'database_info', 'version', 1275, 'backup', $backup );
	$version = 1275;
	sql::end_transaction( $dbh, $ac );
} # end if
if ( $version < 1282 ) {
	print "Updating to version 1282\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('alter table papers add grain_direction text');
	sql::update( undef, undef, 'papers', 'width > height', 'grain_direction', 'Short' );
	sql::update( undef, undef, 'papers', 'width < height', 'grain_direction', 'Long' );
	sql::insert( undef, undef, 'database_info', 'version', 1282, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1282;
} # end if
if ( $version < 1291 ) {
	print "Updating to version 1291\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('alter table material_specifications add interpolate boolean');
	sql::insert( undef, undef, 'database_info', 'version', 1291, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1291;
} # end if
if ( $version < 1333 ) {
	print "Updating to version 1333\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('alter table papers add basis_width float');
	$dbh->do('alter table papers add basis_height float');
	$dbh->do('alter table papers add basis_mweight float');
	sql::update( undef, undef, 'papers', "type='Roll'", 'basis_width', 25, 'basis_height', 38 );
	sql::insert( undef, undef, 'database_info', 'version', 1333, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1333;
} # end if
if ( $version < 1334 ) {
	print "Updating to version 1334\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('alter table papers add grade integer');
	sql::insert( undef, undef, 'database_info', 'version', 1334, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1334;
} # end if
if ( $version < 1381 ) {
	print "Updating to version 1381\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('alter table tbl_ink_colours rename to inks');
	$dbh->do('create sequence inks_id_seq');
	$dbh->do('alter table inks add id INTEGER');
	$dbh->do(q{alter table inks alter id set default nextval('inks_id_seq')});
	$dbh->do(q{DELETE FROM inks WHERE strpmsid like 'PMS%'});
	$dbh->do(q{DELETE FROM inks WHERE strpmsid like 'pms%'});
	$dbh->do(q{update inks set id=nextval('inks_id_seq')});
	$dbh->do(q{alter table inks alter id set NOT NULL});
	$dbh->do(q{alter table inks add service_id INTEGER});
	$dbh->do(q{alter table inks add material_id INTEGER});
	$dbh->do(q{update inks set service_id=(SELECT lngindex from tbl_Services where strid=strserviceid)});
	$dbh->do(q{update inks set material_id=(SELECT lngindex from tbl_Materials where strid=strmaterialid)});
	$dbh->do(q{alter table inks add washups integer});
	$dbh->do(q{alter table inks drop strserviceid});
	$dbh->do(q{alter table inks drop strmaterialid});
	$dbh->do(q{alter table inks rename column strpmsid to pmsid});
	$dbh->do(q{alter table inks add foreign key (material_id) REFERENCES tbl_Materials (lngIndex)});
	$dbh->do(q{alter table inks add foreign key (service_id) REFERENCES tbl_Services (lngIndex)});
	$dbh->do(q{alter table inks add PRIMARY key (id)});
	$dbh->do(q{update inks set washups=1});
	sql::insert( undef, undef, 'database_info', 'version', 1381, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1381;
	
}
if ( $version < 1456 ) {
	print "Updating to version 1456\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do(q{alter table skids add updated_on timestamp with time zone default NOW()});
	$dbh->do(q{update skids set updated_on=NOW()});
	$dbh->do(q{alter table skids add updated_by INTEGER});
	$dbh->do(q{update skids set updated_by=created_by_id});
	$dbh->do(q{alter table skids alter updated_by SET NOT NULL});
	$dbh->do(q{alter table skids ADD FOREIGN KEY (updated_by) REFERENCES Users (Index)});
	sql::insert( undef, undef, 'database_info', 'version', 1456, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1456;
} # end if 1456
if ( $version < 1540 ) {
	print "Updating to version 1540\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do(q{alter table Users drop column ysnHTMLEmails});
	$dbh->do(q{alter table Users drop column stremployeetype});
	$dbh->do(q{alter table Users drop column strmailserverusername});
	$dbh->do(q{alter table Users drop column strmailserverpassword});
	$dbh->do(q{alter table Users drop column lastlogin});

$dbh->do(q{alter table tbl_Service_Types rename column strid to name});
$dbh->do(q{alter table tbl_Service_Types rename column strname to description});
$dbh->do(q{alter table tbl_service_types drop column strbasicurl});
$dbh->do(q{alter table tbl_service_types drop column strtemplateurl});
$dbh->do(q{alter table tbl_service_types drop column stremployeeurl});
$dbh->do(q{alter table tbl_Service_types add create_visible boolean});
$dbh->do(q{update tbl_Service_types set create_visible=true where ysncreatevisible='Y'});
$dbh->do(q{update tbl_Service_types set create_visible=true where ysncreatevisible='Y'});
$dbh->do(q{alter table tbl_Service_Types add view_visible boolean});
$dbh->do(q{update tbl_Service_types set view_visible=true where ysnviewvisible='Y'});
$dbh->do(q{alter table tbl_Service_Types rename column lngsort to sorting});
$dbh->do(q{alter table tbl_service_types drop ysncreatevisible});
$dbh->do(q{alter table tbl_service_types drop ysnviewvisible});
$dbh->do(q{alter table tbl_service_types rename column lngindex to id});
$dbh->do(q{alter table tbl_Service_Types rename to Service_Types});
$dbh->do(q{alter table service_types rename column strcategory to category});
	sql::insert( undef, undef, 'database_info', 'version', 1540, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1540;
} # end if
if ( $version < 1586 ) {
	print "Updating to version 1586\n";
	my $ac = sql::start_transaction( $dbh );
$dbh->do(q{alter table tbl_Materials rename column lngindex to id});
$dbh->do(q{alter table tbl_Materials rename column strid to name});
$dbh->do(q{alter table tbl_Materials rename column strname to description});
$dbh->do(q{alter table tbl_Materials drop column strdetails});
$dbh->do(q{alter table tbl_Materials drop column strdescription});
$dbh->do(q{alter table tbl_Materials rename column lngsupplierindex to supplier_id});
$dbh->do(q{alter table tbl_Materials rename column lngcategoryindex to category_id});
$dbh->do(q{alter table tbl_Materials rename column ysntaxexempt1 to taxexempt1});
$dbh->do(q{alter table tbl_Materials rename column ysntaxexempt2 to taxexempt2});
$dbh->do(q{alter table tbl_Materials rename to Materials});
	sql::insert( undef, undef, 'database_info', 'version', 1586, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1586;
} # end if

if ( $version < 1587 ) {
	print "Updating to version 1587\n";
	my $ac = sql::start_transaction( $dbh );
$dbh->do(q{alter table tbl_Material_Categories rename column lngindex to id});
$dbh->do(q{alter table tbl_Material_Categories rename column strid to name});
$dbh->do(q{alter table tbl_Material_Categories drop column strname});
$dbh->do(q{alter table tbl_Material_Categories rename to Material_Categories});
$dbh->do(q{ALTER TABLE Materials ADD foreign key (category_id) REFERENCES Material_Categories (id)});
	sql::insert( undef, undef, 'database_info', 'version', 1587, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1587;
} # end if
if ( $version < 1600 ) {
	print "Updating to version 1600\n";
	my $ac = sql::start_transaction( $dbh );
$dbh->do(q{alter table tbl_Services rename column lngindex to id});
$dbh->do(q{alter table tbl_Services rename column strid to name});
$dbh->do(q{alter table tbl_Services rename column strname to description});
$dbh->do(q{alter table tbl_Services drop column strdetails});
$dbh->do(q{alter table tbl_Services drop column strdescription});
$dbh->do(q{alter table tbl_Services rename column lngsupplierindex to supplier_id});
$dbh->do(q{alter table tbl_Services rename column lngcategoryindex to category_id});
$dbh->do(q{alter table tbl_Services rename column ysntaxexempt1 to taxexempt1});
$dbh->do(q{alter table tbl_Services rename column ysntaxexempt2 to taxexempt2});
$dbh->do(q{alter table tbl_Services rename to Services});
	sql::insert( undef, undef, 'database_info', 'version', 1600, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1600;
} # end if
if ( $version < 1601 ) {
	print "Updating to version 1601\n";
	my $ac = sql::start_transaction( $dbh );
$dbh->do(q{alter table tbl_Service_Categories rename column lngindex to id});
$dbh->do(q{alter table tbl_Service_Categories rename column strid to name});
$dbh->do(q{alter table tbl_Service_Categories drop column strname});
$dbh->do(q{alter table tbl_Service_Categories rename to Service_Categories});
$dbh->do(q{update Services set category_id=NULL where category_id NOT IN (SELECT id FROM Service_Categories)});
$dbh->do(q{ALTER TABLE Services ADD foreign key (category_id) REFERENCES Service_Categories (id)});
	sql::insert( undef, undef, 'database_info', 'version', 1601, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1601;
} # end if
if ( $version < 1895 ) {
	print "Updating to version 1895\n";
	my $ac = sql::start_transaction( $dbh );
sql::insert(undef,undef,'configuration', [
    'name'=>'UseCaptchaOnRegistration',
    'value'=>'N',
    'type'=>'yes/no',
    'description'=>'Use a CAPTCHA on the registration to protect against automated bots.',
    'category'=> 'Captcha Settings'] );
sql::insert(undef,undef,'configuration', [
    'name'=>'RegistrationCaptchaLength',
    'value'=>'3',
    'type'=>'text',
    'description'=>'Number of characters in the CAPTCHA on the registration page.',
    'category'=> 'Captcha Settings'] );
$dbh->do(q{alter table users add howdidyouhearaboutusother text});
	sql::insert( undef, undef, 'database_info', 'version', 1895, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1895;
} # end if
if ( $version < 1897 ) {
	print "Updating to version 1897\n";
	my $ac = sql::start_transaction( $dbh );
$dbh->do(q{alter table products rename column ysntaxexempt1 to taxexempt1});
$dbh->do(q{alter table products rename column ysntaxexempt2 to taxexempt2});
	sql::insert( undef, undef, 'database_info', 'version', 1897, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1897;
} # end if

if ( $version < 1898 ) {
	print "Updating to version 1898\n";
	my $ac = sql::start_transaction( $dbh );
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM paper_inventory LIMIT 1', {} );
$dbh->do(q{alter table paper_inventory rename column updatetime to updated_on}) if exists $$data{'updatetime'};
if ( ! exists $$data{'id'} ) {
$dbh->do(q{alter table paper_inventory add id integer});
$dbh->do(q{create sequence paperinventory_id_seq});
$dbh->do(q{alter table paper_inventory alter id set nextval('paperinventory_id_seq')});
$dbh->do(q{update paper_inventory set id=nextval('paperinventory_id_seq')});
$dbh->do(q{alter table paper_inventory alter id set not null});
$dbh->do(q{alter table paper_inventory add primary key(id)});
} # end if

	sql::insert( undef, undef, 'database_info', 'version', 1898, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1898;
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM skid_verifications LIMIT 1', {} );
if ( ! $data ) {
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('DROP TABLE IF EXISTS skid_verifications');
	$dbh->do('
CREATE TABLE skid_verifications (
    id SERIAL NOT NULL,
    skid_id INTEGER NOT NULL, FOREIGN KEY (skid_id) REFERENCES skids (id),
    code    TEXT,
    created_on  TIMESTAMP WITH TIME ZONE NOT NULL default NOW(),
    PRIMARY KEY (id)
);' );
$dbh->do('CREATE INDEX skid_verifications_skid_id_idx ON skid_verifications (skid_id);');
$dbh->do('CREATE INDEX skid_verifications_code_idx ON skid_verifications (code);');
	sql::end_transaction( $dbh, $ac );
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM purchaseorders LIMIT 1', {} );
if ( ! $data ) {
} else {
	if ( ! exists $$data{'po_id'} ) {
		$dbh->do('ALTER TABLE Manifests add po_id INTEGER');
		$dbh->do('ALTER TABLE Manifests add FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id)');
	} # end if
	if ( ! exists $$data{'supplier_id'} ) {
		$dbh->do('ALTER TABLE Manifests add supplier_id INTEGER');
		$dbh->do('ALTER TABLE Manifests add FOREIGN KEY (supplier_id) REFERENCES Company (index)');
	} # end if
	if ( ! exists $$data{'docket'} ) {
		$dbh->do('ALTER TABLE Manifests add docket INTEGER');
	} # end if
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM purchaseorders LIMIT 1', {} );
if ( ! $data ) {
} else {
	if ( ! exists $$data{'federaltax_charge'} ) {
		$dbh->do('ALTER TABLE purchaseorders add federaltax_charge BOOLEAN');
	} # end if
	if ( ! exists $$data{'statetax_charge'} ) {
		$dbh->do('ALTER TABLE purchaseorders add statetax_charge BOOLEAN');
	} # end if
	if ( ! exists $$data{'authorized'} ) {
		$dbh->do('ALTER TABLE purchaseorders add authorized BOOLEAN');
		$dbh->do('UPDATE purchaseorder set authorized=true WHERE authorized_on IS NOT NULL');
	} # end if
	if ( ! exists $$data{'manifest_id'} ) {
		$dbh->do('ALTER TABLE purchaseorders add manifest_id TEXT');
		$dbh->do('ALTER TABLE purchaseorders add FOREIGN KEY (manifest_id) REFERENCES Manifests (id)');
	} # end if
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM purchaseorder_contents LIMIT 1', {} );
if ( ! $data ) {
	$dbh->do('
CREATE TABLE PurchaseOrder_COntents (
    id SERIAL NOT NULL,
    po_id   INTEGER NOT NULL, FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id),
    qty     float,
    price   float,
    total   float,
    item    text,
    docket  text,
    description text,
    PRIMARY KEY (id)
);');
} # en dif

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM users LIMIT 1', {} );
if ( ! exists $$data{'purchasing_limit'} ) {
	$dbh->do('ALTER TABLE Users ADD purchasing_limit FLOAT');
} # end if
if ( ! exists $$data{'purchasing_total_limit'} ) {
	$dbh->do('ALTER TABLE Users ADD purchasing_total_limit FLOAT');
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM RFIDScanners LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'monitor'} ) {
	$dbh->do('ALTER TABLE RFIDScanners ADD monitor boolean not null default false');
	} # end if
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Equipment LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'location_id'} ) {
		$dbh->do('ALTER TABLE tbl_Equipment ADD location_id INTEGER');
		$dbh->do('ALTER TABLE tbl_Equipment ADD FOREIGN KEY (location_id) REFERENCES Locations (id)');
	} # end if
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM skid_contents LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'id'} ) {
		$dbh->do('alter table skid_contents add id serial');
		$dbh->do('alter table skid_contents drop constraint skid_contents_pkey');
		$dbh->do('alter table skid_contents add primary key (id)');
		$dbh->do('create index skid_contents_skid_id_idx on skid_contents (skid_id)');
	} # end if
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM manifestcontents LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'docket'} ) {
		$dbh->do('alter table manifestcontents add docket integer');
	} # end if
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM company LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'notes'} ) {
		$dbh->do('alter table company add notes text');
	} # end if
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM users LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'notes'} ) {
		$dbh->do('alter table users add notes text');
	} # end if
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Skids LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'type'} ) {
		$dbh->do('alter table skids add type text');
		$dbh->do('alter table skids add deleted boolean not null default false');
	} # end if
} # end if
foreach my $PI ( openprint::PaperInventory::find('docket'=>undef) ) {
	$PI->save() if $PI->docket();
} # end foreach

$dbh->disconnect();
1;
__END__
