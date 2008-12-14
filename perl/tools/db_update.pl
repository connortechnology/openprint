#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Paper;
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

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
$openprint::Object::no_cache = 1;

$log = new logger( 'warn' );

$ARGV[1] = $ARGV[0] if ! $ARGV[1];
$ARGV[2] = $ARGV[0] if ! $ARGV[2];

$dbh = sql::open_sql( $log, ('database'=>$ARGV[0], 'driver'=>'Pg','login'=>$ARGV[1], 'password'=>$ARGV[2]) );

my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
print "Current Database Version: $version Backups: $backup, Last Updated: $updated_on\n";

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Projects LIMIT 1', {} );
if ( $data ) {
	my $ac = sql::start_transaction( $dbh );
	if ( ! exists $$data{'style_id'} ) {
		$dbh->do('ALTER TABLE tbl_Projects ADD style_id INTEGER');
		$dbh->do('ALTER TABLE tbl_Projects ADD FOREIGN KEY (style_id) REFERENCES QuoteLevels (id)');
	} # end if
	if ( ! exists $$data{'rush'} ) {
		print "Adding rush to projects";
		$dbh->do(q`alter table tbl_Projects add rush boolean default false`);
	} # end if
	if ( ! exists $$data{'predefined'} ) {
		print "Adding predefined to tbl_Projects\n";
		$dbh->do(q`alter table tbl_Projects add predefined boolean`);
		$dbh->do(q`alter table tbl_Projects alter predefined set default false`);
		$dbh->do(q`update tbl_Projects set predefined=false`);
		$dbh->do(q`alter table tbl_Projects alter predefined set not null`);
	} # end if
	sql::end_transaction( $dbh, $ac );
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Users LIMIT 1', {} );
if ( $data ) {
	print "Updating Users...\n";
	if ( ! exists $$data{'deleted'} ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do(q`alter table Users add deleted boolean`);
		$dbh->do(q`alter table Users alter deleted set default false`);
		$dbh->do(q`update Users set deleted=false`);
		$dbh->do(q`alter table Users alter deleted set not null`);
		sql::end_transaction( $dbh, $ac );
	} 
	if ( ! exists $$data{'wage'} ) {
		$dbh->do(q`alter table Users add wage float`);
	} # end if
	if ( exists $$data{'strfirstname'} ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do(q`alter table Users rename column strfirstname to firstname`);
		$dbh->do(q`alter table Users rename column strlastname to lastname`);
		$dbh->do(q`alter table Users rename column stremail to email`);
		$dbh->do(q`alter table Users rename column strphone to phone`);
		$dbh->do(q`alter table Users rename column strfax to fax`);
		$dbh->do(q`alter table Users rename column strtitle to title`);
		$dbh->do(q`alter table Users rename column strsalutation to salutation`);
		$dbh->do(q`alter table Users rename column dtmdateentered to created_on`);
		$dbh->do(q`alter table Users rename column dtmlastmodified to updated_on`);
		$dbh->do(q`alter table Users rename column chrtype to usertype`);
		sql::end_transaction( $dbh, $ac );
	}
	$dbh->do(q{alter table Users drop column ysnHTMLEmails}) if exists $$data{'ysnhtmlemails'};
	$dbh->do(q{alter table Users drop column stremployeetype}) if exists $$data{'stremployeetype'};
	$dbh->do(q{alter table Users drop column strmailserverusername}) if exists $$data{'strmailserverusername'};
	$dbh->do(q{alter table Users drop column strmailserverpassword}) if exists $$data{'strmailserverpassword'};
	$dbh->do(q{alter table Users drop column lastlogin}) if exists $$data{'lastlogin'};
	$dbh->do(q{alter table Users rename column index to id}) if exists $$data{'index'};
	$dbh->do(q`alter table users add deleted boolean`) if ! exists $$data{'deleted'};
	$dbh->do(q`alter table users add email_quotes_to_myself boolean default false`) if ! exists $$data{'email_quotes_to_myself'};
	$dbh->do('ALTER TABLE USERS RENAME COLUMN ysnaccountactivation TO web_active') if $$data{'ysnaccountactivation'};
	$dbh->do('ALTER TABLE USERS RENAME COLUMN companyindex TO company_id') if $$data{'companyindex'};
} # end if

my $new_version = 1273;
if ( $version < $new_version ) {
    print "Updating to version $new_version\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Manufacturers LIMIT 1', {} );
    my $ac = sql::start_transaction( $dbh );
	if ( ! $data ) {
		$_ = misc::load_file( $log, q{../openprint/sql/Manufacturers.sql});
		foreach my $st ( split(';', $_ ) ) {
			$dbh->do($st);
		}
	} 
    die if sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
    sql::end_transaction( $dbh, $ac );
    $version = $new_version;
} # end if


my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Equipment LIMIT 1', {} );
if ( ! $data ) {
} else {
	if ( exists $$data{'lngindex'} ) {
	print "Updating Equipment...\n";
		$dbh->do('ALTER TABLE tbl_Equipment rename  column lngindex to id;');
	} # end if
} # end if


print "Updating Companies\n";
my $data1 = $openprint::dbh->selectrow_hashref( 'SELECT * FROM companies LIMIT 1', {} );
my $data2 = $openprint::dbh->selectrow_hashref( 'SELECT * FROM company LIMIT 1', {} );
my $ac = sql::start_transaction( $dbh );
if ( ! $data1 ) {
	if ( ! $data2 ) {
		$_ = misc::load_file( $log, q{../openprint/sql/Companies.sql});
		foreach my $st ( split(';', $_ ) ) {
			$dbh->do($st);
		}
	} else {
	print "Renaming company to companies\n";
		$dbh->do('ALTER TABLE Company RENAME TO Companies');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strName TO name');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strAddress1 TO address1');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strAddress2 TO address2');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strcity TO city');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strstate TO state') if exists $$data2{'strstate'};
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strcountry TO country');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strpostalcode TO postalcode');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN dtmdateentered TO created_on');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN dtmlastupdated TO updated_on') if exists $$data2{'dtmlastupdated'};
		$dbh->do('ALTER TABLE Companies RENAME COLUMN dtmlastmodified TO updated_on') if exists $$data2{'dtmlastmodified'};
		$dbh->do('ALTER TABLE Companies RENAME COLUMN lngpricelist TO pricelist_id');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strgstnumber TO fedtaxnumber');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strpstnumber TO statetaxnumber');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strphone TO phone');
		$dbh->do('ALTER TABLE Companies RENAME COLUMN strfax TO fax');

		$dbh->do(q`alter table Companies rename column index to id`);
		$dbh->do(q`alter table Companies rename column strprovstate to state`) if exists $$data2{'strprovstate'};
		$dbh->do(q`alter table Companies rename column lngsalesperson to salesrep_id`);
		$dbh->do(q`alter table Companies rename column strweburl to url`);
		$dbh->do(q`alter table Companies rename column strcustomgreeting to greeting`);
		$dbh->do(q`alter table Companies rename column dblpricingpercent to discount`);
		$dbh->do(q`alter table Companies rename column strbusinesstype to business_type`);
		$dbh->do(q`alter table Companies rename column strlegalbusname to business_name`);
		$dbh->do(q`alter table Companies rename column legalform to business_form`);
		$dbh->do(q`alter table Companies rename column strpresidentowner to president_owner`);
		$dbh->do(q`alter table Companies rename column dtmbusinessstartdate to established`);
		$dbh->do(q`alter table Companies rename column stremployees to employees`);
		$dbh->do(q`alter table Companies rename column strannualsales to annual_sales`);
		$dbh->do(q`alter table Companies rename column strbankname to bank_name`);
		$dbh->do(q`alter table Companies rename column strbankbranch to bank_branch`);
		$dbh->do(q`alter table Companies rename column strbankphone to bank_phone`);
		$dbh->do(q`alter table Companies rename column strbankaccountno to bank_account`);
		$dbh->do(q`alter table Companies rename column strbankaccountmanager to bank_manager`);
		$dbh->do(q`alter table Companies rename column strbankfax to bank_fax`);
		$dbh->do(q`alter table Companies rename column strbankemail to bank_email`);
		$dbh->do('CREATE SEQUENCE companies_id_seq');
		$dbh->do(q`SELECT setval('companies_id_seq', (SELECT MAX(id) FROM Companies))`);
		$dbh->do(q`ALTER TABLE companies alter id set default nextval('companies_id_seq')`);
		$dbh->do('DROP SEQUENCE IF EXISTS tbl_Customer_lngCustomerID_seq');
		$dbh->do('DROP SEQUENCE IF EXISTS companyindex_seq');
	} # end if
} # end if
sql::end_transaction( $dbh, $ac );

if ( $version < 1275 ) {
	print "Updating to version 1275\n";
	
	my $ac;
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM papers LIMIT 1', {} );
    if ( ! $data ) {
        $ac = sql::start_transaction( $dbh );
        $_ = misc::load_file( $log, q{../openprint/sql/Papers.sql});
        foreach my $st ( split(';', $_ ) ) {
            $dbh->do($st);
        }
	} else {
		$ac = sql::start_transaction( $dbh );
		$dbh->do('alter table papers add bladecleaning boolean');
		sql::update( undef, undef, 'papers', 'bladecleaning IS NULL', 'bladecleaning', 'false' );
    } # end if
	die if sql::insert( undef, undef, 'database_info', 'version', 1275, 'backup', $backup );
	$version = 1275;
	sql::end_transaction( $dbh, $ac );
} # end if
if ( $version < 1282 ) {
	print "Updating to version 1282\n";
	my $ac = sql::start_transaction( $dbh );
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM papers LIMIT 1', {} );
	if ( ! exists $$data{'grain_direction'} ) {
		$dbh->do('alter table papers add grain_direction text');
		sql::update( undef, undef, 'papers', 'width > height', 'grain_direction', 'Short' );
		sql::update( undef, undef, 'papers', 'width < height', 'grain_direction', 'Long' );
	} # end if
	sql::insert( undef, undef, 'database_info', 'version', 1282, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1282;
} # end if
if ( $version < 1291 ) {
	print "Updating to version 1291\n";
	my $data1 = $openprint::dbh->selectrow_hashref( 'SELECT * FROM materials LIMIT 1', {} );
	my $data2 = $openprint::dbh->selectrow_hashref( 'SELECT * FROM material_specifications LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
    if ( ! $data1 ) {
        $_ = misc::load_file( $log, q{../openprint/sql/Materials.sql});
        foreach my $st ( split(';', $_ ) ) {
            $dbh->do($st);
        }
	} # end if
    if ( ! $data2 ) {
        $_ = misc::load_file( $log, q{../openprint/sql/Material_Specifications.sql});
        foreach my $st ( split(';', $_ ) ) {
            $dbh->do($st);
        }
	} else {
	$dbh->do('alter table material_specifications add interpolate boolean');
	} # end if
	die if sql::insert( undef, undef, 'database_info', 'version', 1291, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1291;
} # end if
if ( $version < 1333 ) {
	print "Updating to version 1333\n";
	my $ac = sql::start_transaction( $dbh );
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM papers LIMIT 1', {} );
	$dbh->do('alter table papers add basis_width float') if ! exists $$data{basis_width};
	$dbh->do('alter table papers add basis_height float') if ! exists $$data{basis_height};
	$dbh->do('alter table papers add basis_mweight float') if ! exists $$data{basis_mweight};
	sql::update( undef, undef, 'papers', "type='Roll'", 'basis_width', 25, 'basis_height', 38 );
	sql::insert( undef, undef, 'database_info', 'version', 1333, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1333;
} # end if
if ( $version < 1334 ) {
	print "Updating to version 1334\n";
	my $ac = sql::start_transaction( $dbh );
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM papers LIMIT 1', {} );
	$dbh->do('alter table papers add grade integer') if ! exists $$data{'grade'};
	sql::insert( undef, undef, 'database_info', 'version', 1334, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1334;
} # end if
if ( $version < 1381 ) {
	print "Updating to version 1381\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_ink_colours LIMIT 1', {} );
	my $data2 = $openprint::dbh->selectrow_hashref( 'SELECT * FROM inks LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( $data ) {
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
	} elsif ( ! $data2) {
        $_ = misc::load_file( $log, q{../openprint/sql/Inks.sql});
        foreach my $st ( split(';', $_ ) ) {
            $dbh->do($st);
        }

	} # end if
	die if sql::insert( undef, undef, 'database_info', 'version', 1381, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1381;
	
}
if ( $version < 1456 ) {
	print "Updating to version 1456\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM skids LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( ! $data ) {
        $_ = misc::load_file( $log, q{../openprint/sql/Skids.sql});
        foreach my $st ( split(';', $_ ) ) {
            $dbh->do($st);
        }
	} else {
	$dbh->do(q{alter table skids add updated_on timestamp with time zone default NOW()});
	$dbh->do(q{update skids set updated_on=NOW()});
	$dbh->do(q{alter table skids add updated_by INTEGER});
	$dbh->do(q{update skids set updated_by=created_by_id});
	$dbh->do(q{alter table skids alter updated_by SET NOT NULL});
	$dbh->do(q{alter table skids ADD FOREIGN KEY (updated_by) REFERENCES Users (id)});
	} # end if
	die if sql::insert( undef, undef, 'database_info', 'version', 1456, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1456;
} # end if 1456
if ( $version < 1540 ) {
	print "Updating to version 1540\n";
	my $data2 = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Service_types LIMIT 1', {} );
	my $data3 = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Service_types LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( $data2 ) {
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
	} elsif ( ! $data3 ) {
		$_ = misc::load_file( $log, q{../openprint/sql/Service_Types.sql});
		foreach my $st ( split(';', $_ ) ) {
			$dbh->do($st);
		}
	} # end if
	die if sql::insert( undef, undef, 'database_info', 'version', 1540, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1540;
} # end if
if ( $version < 1586 ) {
	print "Updating to version 1586\n";
	
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Materials LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
if ( $data ) {
$dbh->do(q{alter table tbl_Materials rename column lngindex to id}) if ! exists $$data{id};
$dbh->do(q{alter table tbl_Materials rename column strid to name}) if ! exists $$data{name};
$dbh->do(q{alter table tbl_Materials rename column strname to description}) if ! exists $$data{description};
$dbh->do(q{alter table tbl_Materials drop column strdetails}) if exists $$data{strdetails};
$dbh->do(q{alter table tbl_Materials drop column strdescription}) if exists $$data{strdescription};
$dbh->do(q{alter table tbl_Materials rename column lngsupplierindex to supplier_id}) if ! exists $$data{supplied_id};
$dbh->do(q{alter table tbl_Materials rename column lngcategoryindex to category_id}) if ! exists $$data{category_id};

$dbh->do(q{alter table tbl_Materials rename column ysntaxexempt1 to taxexempt1}) if exists $$data{ysntaxexempt1};
$dbh->do(q{alter table tbl_Materials rename column ysntaxexempt2 to taxexempt2}) if exists $$data{ysntaxexempt2};
$dbh->do(q{alter table tbl_Materials rename to Materials});
} # endif
	die if sql::insert( undef, undef, 'database_info', 'version', 1586, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1586;
} # end if

if ( $version < 1587 ) {
	print "Updating to version 1587\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Material_Categories LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
if ( $data ) {
$dbh->do(q{alter table tbl_Material_Categories rename column lngindex to id});
$dbh->do(q{alter table tbl_Material_Categories rename column strid to name});
$dbh->do(q{alter table tbl_Material_Categories drop column strname});
$dbh->do(q{alter table tbl_Material_Categories rename to Material_Categories});
$dbh->do(q{ALTER TABLE Materials ADD foreign key (category_id) REFERENCES Material_Categories (id)});
} # end if
	die if sql::insert( undef, undef, 'database_info', 'version', 1587, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1587;
} # end if
if ( $version < 1600 ) {
	print "Updating to version 1600\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Services LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
if ( $data ) {
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
}
	die if sql::insert( undef, undef, 'database_info', 'version', 1600, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1600;
} # end if
if ( $version < 1601 ) {
	print "Updating to version 1601\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Service_Categories LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
if ( $data ) {
$dbh->do(q{alter table tbl_Service_Categories rename column lngindex to id});
$dbh->do(q{alter table tbl_Service_Categories rename column strid to name});
$dbh->do(q{alter table tbl_Service_Categories drop column strname});
$dbh->do(q{alter table tbl_Service_Categories rename to Service_Categories});
$dbh->do(q{update Services set category_id=NULL where category_id NOT IN (SELECT id FROM Service_Categories)});
$dbh->do(q{ALTER TABLE Services ADD foreign key (category_id) REFERENCES Service_Categories (id)});
} # end if
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
	die if sql::insert( undef, undef, 'database_info', 'version', 1895, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1895;
} # end if
if ( $version < 1897 ) {
	print "Updating to version 1897\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM products LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	my $blah = $dbh->selectrow_hashref( 'SELECT * FROM products LIMIT 1', {} );
	if ( exists $$blah{'ysntaxexempt1'} ) {
		if ( ! exists $$blah{'taxexempt1'} ) {
			$dbh->do(q{alter table products rename column ysntaxexempt1 to taxexempt1});
		} else {
			$dbh->do(q{alter table products drop column ysntaxexempt1});
		} # end if
	} # end if
	if ( exists $$blah{'ysntaxexempt2'} ) {
		if ( ! exists $$blah{'taxexempt2'} ) {
			$dbh->do(q{alter table products rename column ysntaxexempt2 to taxexempt2});
		} else {
			$dbh->do(q{alter table products drop column ysntaxexempt2});
		} # end if
	} # end if
	sql::insert( undef, undef, 'database_info', 'version', 1897, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1897;
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM paper_inventory LIMIT 1', {} );
if ( $data ) {
	my $ac = sql::start_transaction( $dbh );
	$dbh->do(q{alter table paper_inventory rename column updatetime to updated_on}) if exists $$data{'updatetime'};
	if ( ! exists $$data{'id'} ) {
		$dbh->do(q{alter table paper_inventory add id integer});
		$dbh->do(q{create sequence paperinventory_id_seq});
		$dbh->do(q{alter table paper_inventory alter id set default nextval('paperinventory_id_seq')});
		$dbh->do(q{update paper_inventory set id=nextval('paperinventory_id_seq')});
		$dbh->do(q{alter table paper_inventory alter id set not null});
		$dbh->do(q{alter table paper_inventory add primary key(id)});
	} # end if
	sql::end_transaction( $dbh, $ac );
} # end if
if ( $version < 1898 ) {
	print "Updating to version 1898\n";
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM StockPurposes LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( !$data ) {
		$dbh->do(q{CREATE TABLE StockPurposes (
					id  SERIAL NOT NULL,
					name   TEXT NOT NULL,
					PRIMARY KEY (id)
					)});
	} # end if
	sql::end_transaction( $dbh, $ac );
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Skids LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( ! exists $$data{'purpose_id'} ) {
		$dbh->do(q{alter table skid_contents add purpose_id integer});
		$dbh->do(q{alter table skid_contents add foreign key (purpose_id) references stockpurposes (id)});
		$dbh->do(q{insert into stockpurposes (name) values ('House Stock')});
		$dbh->do(q{insert into stockpurposes (name) values ('Job Stock')});
		$dbh->do(q{insert into stockpurposes (name) values ('Sample')});
	}
	die if sql::insert( undef, undef, 'database_info', 'version', 1898, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1898;
} # end if
if ( $version < 1899 ) {
	print "Updating to version 1899\n";
	$dbh->do(q{alter table skid_contents add primary key (skid_id, paper_id)});
	my $ac = sql::start_transaction( $dbh );
	$dbh->do(q{drop index if exists "skid_contents_skid_id_index"});
	sql::insert( undef, undef, 'database_info', 'version', 1899, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1899;
} # end if
if ( $version < 1900 ) {
	print "Updating to version 1900\n";
	my $blah = $dbh->selectrow_hashref( 'SELECT * FROM Quote_log LIMIT 1', {} );
	if ( ! $blah ) {
	$dbh->do(q{
			CREATE TABLE Quote_Log (
				quote_id    INTeger NOT NULL, FOREIGN KEY(quote_Id) REFERENCES tbl_Quotes (index),
				Company_id  INTeger NOT NULL, FOREIGN KEY(company_id) REFERENCES Companies (id),
				User_id     INTeger NOT NULL, FOREIGN KEY(user_id) REFERENCES Users (id),
				dtmwhen     timestamp with time zone NOT NULL default(NOW()),
				Description         TEXT,
				PRIMARY KEY (quote_Id,dtmwhen)
				)
			});
	} # end if
	sql::insert( undef, undef, 'database_info', 'version', 1900, 'backup', $backup );
	$version = 1900;
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Service_Prices LIMIT 1', {} );
if ( $data ) {
my $ac = sql::start_transaction( $dbh );
	$dbh->do('ALTER TABLE tbl_Service_Prices RENAME TO Service_Prices');
	$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN lnglistindex TO pricelist_id');
	$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN lngserviceindex TO service_id');
	$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN lngequipmentindex TO equipment_id');
	$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN dblcost TO cost');
	$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN dblmarkup TO markup');
	$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN dblprice TO price');
	$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN strunits TO units');
	$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN ysndiscountable TO discountable');
	$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN lngmin TO min');
	$dbh->do('ALTER TABLE Service_Prices RENAME COLUMN lngmax TO max');
	if ( ! exists $$data{'owner_id'} ) {
		$dbh->do('ALTER TABLE Service_Prices ADD owner_id INTEGER');
		$dbh->do('ALTER TABLE Service_Prices ADD FOREIGN KEY (owner_id) REFERENCES Companies (id)');
	} # end if
sql::end_transaction( $dbh, $ac );
} # end if
if ( $version < 1901 ) {
	print "Updating to version 1901\n";
	my $ac = sql::start_transaction( $dbh );
	my @Services = openprint::Service::find('name'=>'PressUnitMakeReady');
	push @Services, openprint::Service::find('name'=>'PressUnitMakeReadySheet Work');
	if ( @Services ) {
		my $Service = $Services[0];
		foreach my $Equipment ( openprint::Equipment::find('category'=>'Printing') ) {
			foreach my $Price ( openprint::ServicePrice::find('Equipment'=>$Equipment, 'Service'=>$Service )) {
				if ( $$Price{'units'} eq 'Per Unit' ) {
					$$Price{'cost'} = $$Price{'cost'}/$$Price{'min'};
					$$Price{'price'} = $$Price{'price'}/$$Price{'min'};
					$Price->save();
				} # end if
			} # end foreach
		} # end foreach
	} # en dif
	die if sql::insert( undef, undef, 'database_info', 'version', 1901, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1901;
} # end if
if ( $version < 1902 ) {
	print "Updating to version 1902\n";
	my $ac = sql::start_transaction( $dbh );
	my @projects;
	push @projects, openprint::Project::find( 'order'=>'index desc', 'created_on_start'=>sprintf('%.4d-%.2d-%.2d', Date::Calc::Add_Delta_Days( Date::Calc::Today(), -30 ) ) );

	foreach my $Project ( @projects ) {
		my $services = $Project->services();
		foreach my $sig_id ( $Project->signatures() ) {

			my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
			#if ( ! exists $$sig_specs{'Group'} ) {
			if ( $$sig_specs{'txtSignatureType'} ) {
				if ( $$sig_specs{'txtSignatureType'} eq 'Cover Spreads' ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'txtSignatureType', 'Cover Pages' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Group', '1' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'GroupPageQuantity', '4' );
			
				} elsif ( $$sig_specs{'txtSignatureType'} eq 'Interior Spreads' ) {
					my $p_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

				
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'txtSignatureType', 'Interior Pages' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Group', '2' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'GroupPageQuantity', $$p_specs{'txtInteriorSpreadQuantity'} * $$sig_specs{'txtSpreadSize'} );
				} else {
					# Gate Fold?
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Group', '3' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'GroupPageQuantity', '4' );
				} # end if
			} # end if

			foreach my $qty_index ( 1 .. 3 ) {
				if ( $$sig_specs{'chkOverrideSignatureSpreadQuantity'.$qty_index} eq 'Y' and $$sig_specs{'chkOverridePageQuantity'.$qty_index} ne 'Y' ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkOverridePageQuantity'.$qty_index, 'Y' );
					if ( ! $$sig_specs{'PageQuantity'.$qty_index} ) {
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'PageQuantity'.$qty_index, $$sig_specs{'txtSignatureSpreadQuantity'.$qty_index} * $$sig_specs{'txtSpreadSize'} );
					} # end if
					openprint::service::delete_service_spec( $Project->id(), $sig_id, 'chkOverrideSignatureSpreadQuantity'.$qty_index );
				} # end if
				openprint::service::delete_service_spec( $Project->id(), $sig_id, 'txtSignatureSpreadQuantity'.$qty_index );
		
			} # end foreach qty_index
			#} # end if
		} # end foreach
	} # end foreach
	die if sql::insert( undef, undef, 'database_info', 'version', 1902, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1902;
} # end if
    my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Papers LIMIT 1', {} );
$dbh->do(q{alter table papers add minimum_order integer}) if ! exists $$data{'minimum_order'};
$dbh->do(q{alter table papers add inventory_number	text}) if ! exists $$data{'inventory_number'};
$dbh->do(q{alter table papers add full_packages boolean}) if ! exists $$data{'full_packages'};

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Folds LIMIT 1', {} );
if ( ! $data ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Folds.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Equipment_Specifications LIMIT 1', {} );
if ( $data ) {
	if ( exists $$data{'lngindex'} ) {
		$dbh->do('ALTER TABLE tbl_Equipment_SPecifications rename column lngindex to id');
		$dbh->do('CREATE SEQUENCE tbl_equipment_specifications_id_seq');
		$dbh->do("ALTER TABLE tbl_Equipment_specifications alter column id set default nextval('tbl_equipment_specifications_id_seq')");
		$dbh->do('DROP SEQUENCE EquipmentSpecification_seq');
		$dbh->do("SELECT setval('tbl_equipment_specifications_id_seq', (SELECT MAX(id) FROM tbl_equipment_specifications) )");
	} # end if
} # end if
foreach my $E ( openprint::Equipment::find('Specifications'=>{'Folding Capable'=>'Y'}) ) {
	foreach my $Spec ( $E->Specifications() ) {
		if ( $Spec->name() =~ /^(\d+)PageSignatureFoldRunSpeed$/ ) {
			my $pages = $1;
			my $Fold = new openprint::Fold();
			$Fold->equipment_id( $E->id() );
			$Fold->name( $pages.'PageFold' );
			$Fold->type( $pages . 'PageFold' );
			$Fold->pages( $pages );
			$Fold->max_imposition( $pages == 4 ? 4 : 1 );
			$_ = $Fold->save();
			die $_ if $_;
			my $FS = new openprint::FoldSpecification();
			$FS->fold_id( $Fold->id() );
			$FS->runspeed( $Spec->value() );
			$FS->interpolate( $Spec->interpolate() );
			$_ =  $FS->save();
			die $_ if $_;
			$Spec->delete();
		} elsif ( $Spec->name() =~ /^(\w*)FoldRunSpeed/ ) {
			my $type = $1;
			my $Fold = new openprint::Fold();
			$Fold->equipment_id( $E->id() );
			$Fold->name( $type.'Fold' );
			$Fold->type( $type.'Fold' );
			$Fold->max_imposition( 4 );
			$_ = $Fold->save();
			die $_ if $_;
			my $FS = new openprint::FoldSpecification();
			$FS->fold_id( $Fold->id() );
			$FS->runspeed( $Spec->value() );
			$FS->interpolate( $Spec->interpolate() );
			$_ =  $FS->save();
			die $_ if $_;
			$Spec->delete();
		}
	} 
}
foreach my $E ( openprint::Equipment::find('Specifications'=>{'Folding Capable'=>'When Printing'}) ) {
	foreach my $Spec ( $E->Specifications() ) {
		if ( $Spec->name() =~ /^(\d)x(\d)-(\d*)Page-(\w*)SignatureFoldDescription$/ ) {
			my ( $columns, $rows, $pages, $spine_direction ) = ( $1, $2, $3, $4 );
			my $spread_size = $pages/($columns*$rows);
			my $fold = sprintf('%dx%d-%dPage-%sSignatureFold', $columns, $rows, $pages, $spine_direction );
			my $Fold = new openprint::Fold();
			$Fold->equipment_id( $E->id() );
			$Fold->name( $Spec->value() );
			$Fold->type( $pages . 'PageFold' );
			$Fold->pages( $pages );
			if ( $spread_size == 4 ) {
				$Fold->stitching(1);
				if ( $spine_direction eq 'Vertical' ) {
					$columns *= 2;
				} else {
					$rows *= 2;
				} # end if
			} else {
				$Fold->perfectbind(1);
				$Fold->spinepaste(1);
			} # end if
			$Fold->cutting(0);
			$Fold->page_columns( $columns );
			$Fold->page_rows( $rows );
			$Fold->spine_direction( $spine_direction );
			if ( $_ = $E->Specification( $fold.'MinimumWidth' ) ) {
				$Fold->min_width( sprintf( '%.3f', ($_->value()/$columns)) );
				$_->delete();
			} #end if
			if ( $_ = $E->Specification( $fold.'MaximumWidth' ) ) {
				$Fold->max_width( sprintf('%.3f', ($_->value()/$columns)) );
				$_->delete();
			} # en dif
			if ( $_ = $E->Specification( $fold.'MinimumHeight' ) ) {
				$Fold->min_height( sprintf('%.3f', ($_->value()/$rows)) );
				$_->delete();
			} # end if
			if ( $_ = $E->Specification( $fold.'MaximumHeight' ) ) {
				$Fold->max_height( sprintf('%.3f', ($_->value()/$rows)) );
				$_->delete();
			} # end if
			if ( $_ = $E->Specification( $fold.'MaximumImposition' ) ) {
				$Fold->max_imposition( $_->value() );
				$_->delete();
			} # end if
			if ( $_ = $E->Specification( $fold.'MinimumImposition' ) ) {
				$Fold->min_imposition( $_->value() );
				$_->delete();
			} # end if
			$_ = $Fold->save();
			die $_ if $_;
			while ( my $S = $E->Specification( $fold.'RunSpeed' ) ) {
				my $FS = new openprint::FoldSpecification();
				$FS->fold_id( $Fold->id() );
				$FS->min_weight( $S->min() );
				$FS->max_weight( $S->max() );
				$FS->weight_units( $S->units() );
				$FS->runspeed( $S->value() );
				$FS->interpolate( $S->interpolate() );
				$_ =  $FS->save();
				die $_ if $_;
				$S->delete();
				delete $$E{'Specifications'};
			} # end while
			$Spec->delete();
		} # end if
	} # end foreach
} # end foreach
my $blah = $dbh->selectrow_hashref( 'SELECT * FROM Quote_Log LIMIT 1', {} );
if ( ! $blah ) {
} else {
	if ( $$blah{'dtmwhen'} ) {
		$dbh->do(q{alter table quote_log rename column dtmwhen to created_on});
	} # end if
	if ( ! exists $$blah{'id'} ) {
		$dbh->do(q{alter table quote_log add id SERIAL NOT NULL});
		$dbh->do(q{alter table quote_log drop constraint quote_log_pkey});
		$dbh->do(q{alter table quote_log add PRIMARY KEY (id)});
	} # end if
	if ( ! exists $$blah{'company_id'} ) {
		$dbh->do(q{alter table quote_log add company_id INTEGER});
		$dbh->do(q{alter table quote_log add FOREIGN KEY (company_id) REFERENCES companies (id)});
	} 
} # end if
if ( $version < 1907 ) {
	print "Updating to version 1907\n";
	my $ac = sql::start_transaction( $dbh );
foreach my $E ( openprint::Equipment::find('Specifications'=>{'Type'=>'Press'}) ) {
	my $Spec = $E->Specification('Feed');
	if ( ! $Spec ) {
		$Spec = new openprint::EquipmentSpecification();
		$Spec->equipment_id( $E->id() );
		$Spec->name( 'Feed' );
		$Spec->value('Sheet');
		$Spec->save();
	} elsif ( $Spec->value() eq 'Web' ) {
		$Spec->value('Roll');
		$Spec->save();
	} # end if
} # end foreach
	die if sql::insert( undef, undef, 'database_info', 'version', 1907, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1907;
} # end if
if ( $version < 1908 ) {
	print "Updating to version 1908\n";
	my $ac = sql::start_transaction( $dbh );
	sql::insert( undef, undef, 'configuration', { 'name'=>'ProjectViewDisclaimer','value'=>'','type'=>'text','description'=>'Text to display at the bottom of the project view page', 'category'=>'Disclaimers'} );
	sql::insert( undef, undef, 'configuration', { 'name'=>'OrderViewDisclaimer','value'=>'','type'=>'text','description'=>'Text to display at the bottom of the order view page', 'category'=>'Disclaimers'});
	sql::insert( undef, undef, 'configuration', { 'name'=>'QuoteViewDisclaimer','value'=>'','type'=>'text','description'=>'Text to display at the bottom of the quote view page', 'category'=>'Disclaimers'});

	sql::insert( undef, undef, 'database_info', 'version', 1908, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1908;
} # end if
if ( $version < 1909 ) {
	print "Updating to version 1909\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('drop sequence if exists materialcategoriesindex_seq');
	$dbh->do('drop sequence if exists material_categories_id_seq');
	$dbh->do('create sequence material_categories_id_seq');
	$dbh->do(q{select setval('material_categories_id_seq', (select max(id) from material_categories))});
	$dbh->do(q{alter table material_categories alter column id set default nextval('material_categories_id_seq')});

	sql::insert( undef, undef, 'database_info', 'version', 1909, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1909;
} # end if
if ( $version < 1910 ) {
	print "Updating to version 1910\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('alter table service_types add unique(name);');
	die if sql::insert( undef, undef, 'database_info', 'version', 1910, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1910;
} # end if
if ( $version < 1911 ) {
	print "Updating to version 1911\n";
	my $ac = sql::start_transaction( $dbh );
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Folds LIMIT 1', {} );
	$dbh->do('alter table folds add min_calliper float') if ! exists $$data{'min_calliper'};
	$dbh->do('alter table folds add max_calliper float') if ! exists $$data{'max_calliper'};
	$dbh->do('alter table folds add cutting boolean') if ! exists $$data{'cutting'};
	die if sql::insert( undef, undef, 'database_info', 'version', 1912, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1912;
} # end if
if ( $version < 1913 ) {
	print "Updating to version 1913\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('create sequence service_categories_id_seq;');
	$dbh->do(q`alter table service_categories alter id set default nextval('service_categories_id_seq')`);
	$dbh->do(q`select setval('service_categories_id_seq', (select max(id) from service_categories) )`);
	$dbh->do(q`drop sequence if exists servicecategoriesindex_seq`);
	die if sql::insert( undef, undef, 'database_info', 'version', 1913, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1913;
} # end if
if ( $version < 1914 ) {
	print "Updating to version 1914\n";
	my $ac = sql::start_transaction( $dbh );
	sql::update( undef, undef, 'service_types',['strdetailedurl=?','bind/padding.html'], 'strdetailedurl', 'bind/Padding.html' );
	die if sql::insert( undef, undef, 'database_info', 'version', 1914, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1914;
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

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Labels LIMIT 1', {} );
if ( ! $data ) {
	my $ac = sql::start_transaction( $dbh );
	$_ = misc::load_file( $log, q{../openprint/sql/Labels.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
	sql::end_transaction( $dbh, $ac );
} # end if

if ( $version < 1916 ) {
	print "Updating to version 1916\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM papers LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( ! exists $$data{'message'} ) {
	$dbh->do(q`alter table papers add message text`);
	} # end if
	die if sql::insert( undef, undef, 'database_info', 'version', 1916, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1916;
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM folds LIMIT 1', {} );
my $ac = sql::start_transaction( $dbh );
if ( ! exists $$data{'folds'} ) {
$dbh->do(q`alter table folds add folds integer`);
} # end if
if ( ! exists $$data{'angles'} ) {
$dbh->do(q`alter table folds add angles integer`);
} # end if
foreach my $E ( openprint::Equipment::find() ) {
	foreach my $Fold ( $E->Folds() ) {
		if ( $Fold->type() =~ /(\d*)PageSignatureFold/ ) {
			$Fold->type( "$1PageFold" );
			$Fold->save();
		} # end if
	} # end foreach
} # end foreach
sql::end_transaction( $dbh, $ac );

foreach my $E ( openprint::Equipment::find() ) {
	foreach my $Fold ( $E->Folds() ) {
		if ( $Fold->type() =~ /(\d*)PageFold/ ) {
			sql::update( undef, undef, 'Services', ['name=?', "$1PageSignatureFold"], 'name', "$1PageFold" );
			sql::update( undef, undef, 'Services', ['name=?', "$1PageSignatureFoldMakeReady"], 'name', "$1PageFoldMakeReady" );
		} # end if
	} # end foreach
} # end foreach

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM purchaseorders LIMIT 1', {} );
if ( ! $data ) {
		$_ = misc::load_file( $log, q{../openprint/sql/PurchaseOrders.sql});
		foreach my $st ( split(';', $_ ) ) {
			$dbh->do($st);
		}
} else {
	if ( ! exists $$data{'federaltax_charge'} ) {
		$dbh->do('ALTER TABLE purchaseorders add federaltax_charge BOOLEAN');
	} # end if
	if ( ! exists $$data{'statetax_charge'} ) {
		$dbh->do('ALTER TABLE purchaseorders add statetax_charge BOOLEAN');
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

if ( $version < 1919 ) {
	print "Updating to version 1919\n";
	my $ac = sql::start_transaction( $dbh );

	$_ = misc::load_file( $log, q{../openprint/sql/QuoteLevels.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
#sql::insert( undef, undef, 'QuoteLevels', 'name', 'Simple' );
#sql::insert( undef, undef, 'QuoteLevels', 'name', 'Advanced' );
	$dbh->do(q`alter table Users add quote_level integer`);
	$dbh->do(q`alter table Users add foreign key (quote_level) REFERENCES QuoteLevels (id)`);
	sql::insert( undef, undef, 'database_info', 'version', 1919, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1919;
} # end if
if ( $version < 1920 ) {
	print "Updating to version 1920\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM service_types LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( ! exists $$data{'type'} ) {
		$dbh->do(q`ALTER TABLE service_types ADD type TEXT`);
	} # end if
	$dbh->do(q`UPDATE service_types SET type=name WHERE type IS NULL`);
	sql::insert( undef, undef, 'database_info', 'version', 1920, 'backup', $backup );

	sql::end_transaction( $dbh, $ac );
	$version = 1920;
} # end if
my $new_version = 1921;
if ( $version < $new_version ) {
	print "Updating to version $new_version\n";
	my $ac = sql::start_transaction( $dbh );
	sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
	foreach my $E ( openprint::Equipment::find() ) {
		if ( $E->specification('Double Overs For Covers') eq 'Y' ) {
			sql::insert( undef, undef, 'tbl_Equipment_Specifications',[
					'lngEquipmentIndex',    $E->id(),
					'dblMin',               undef,
					'dblMax',               undef,
					'strUnits',             'Percent',
					'strName',              'Covers Overs Percentage',
					'strValue',             100,
					'interpolate',          0,
					] );

		} else {
			sql::insert( undef, undef, 'tbl_Equipment_Specifications',[
					'lngEquipmentIndex',    $E->id(),
					'dblMin',               undef,
					'dblMax',               undef,
					'strUnits',             'Percent',
					'strName',              'Covers Overs Percentage',
					'strValue',             0,
					'interpolate',          0,
					] );
		} # end if
		sql::execute( undef, undef, 'DELETE FROM tbl_Equipment_Specifications WHERE lngEquipmentindex=? AND strname=?', $E->id(), 'Double Overs For Covers' );
	} # end foreac E
	sql::end_transaction( $dbh, $ac );
	$version = $new_version;
} # end if

foreach my $Type ( openprint::ServiceType::find('name'=>'BulkSkids') ) {
    $Type->type( 'Skids' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType::find('name'=>'PlainCartons') ) {
    $Type->type( 'Skids' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType::find('name'=>'Bundling') ) {
    $Type->type( 'Packaging' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType::find('name'=>'ShrinkWrap') ) {
    $Type->type( 'Packaging' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType::find('name'=>'KraftWrap') ) {
    $Type->type( 'Packaging' );
    $Type->save();
}

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Equipment LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'jdf_name'} ) {
		$dbh->do(q`alter table tbl_equipment add jdf_name text`);
	} # end if
	if ( ! exists $$data{'jdf_id'} ) {
		$dbh->do(q`alter table tbl_equipment add jdf_id text`);
	} # end if
} # end if

    my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM StockGroups LIMIT 1', {} );
    if ( ! $data ) {
        my $ac = sql::start_transaction( $dbh );
        $_ = misc::load_file( $log, q{../openprint/sql/StockGroups.sql});
        foreach my $st ( split(';', $_ ) ) {
            $dbh->do($st);
        }
        sql::end_transaction( $dbh, $ac );
    } # end if
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Papers LIMIT 1', {} );
	if ( ! exists $$data{'group_id'} ) {
		$dbh->do(q`alter table papers add group_id INTEGER`);
		$dbh->do(q`alter table papers add FOREIGN KEY (group_id) REFERENCES StockGroups (id)`);
	} # end if

my $new_version = 1924;
if ( $version < $new_version ) {
    print "Updating to version $new_version\n";
    my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Locations LIMIT 1', {} );
    if ( ! $data ) {
		$_ = misc::load_file( $log, q{../openprint/sql/Locations.sql});
		foreach my $st ( split(';', $_ ) ) {
			$dbh->do($st);
		}
	} # end if
    my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM RFIDTags LIMIT 1', {} );
    if ( ! $data ) {
        my $ac = sql::start_transaction( $dbh );
        $_ = misc::load_file( $log, q{../openprint/sql/RFID.sql});
        foreach my $st ( split(';', $_ ) ) {
            $dbh->do($st);
        }
        sql::end_transaction( $dbh, $ac );
    } # end if
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM skids LIMIT 1', {} );
	if ( ! exists $$data{'rfidtag_id'} ) {
		$dbh->do(q`alter table skids add rfidtag_id TEXT`);
		$dbh->do(q`alter table papers add FOREIGN KEY (rfidtag_id) REFERENCES RFIDTags (id)`);
	} # end if
    die if sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
    $version = $new_version;
} # end if

my $new_version = 1925;
if ( $version < $new_version ) {
    print "Updating to version $new_version\n";
    my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM User_Service_Defaults LIMIT 1', {} );
    if ( ! $data ) {
		my $ac = sql::start_transaction( $dbh );
		$_ = misc::load_file( $log, q{../openprint/sql/User_Service_Defaults.sql});
		foreach my $st ( split(';', $_ ) ) {
			$dbh->do($st);
		}
		sql::end_transaction( $dbh, $ac );
    } # end if
    sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
    $version = $new_version;
} # end if
my $new_version = 1926;
if ( $version < $new_version ) {
    print "Updating to version $new_version\n";
    my $ac = sql::start_transaction( $dbh );
	sql::insert( undef, undef, 'configuration', 'name', 'MinimumPagesWithoutCounting','value','25','description', 'Minimum number of pages per pad before counting is required.', 'category','Miscellaneous Settings' );
    sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
    sql::end_transaction( $dbh, $ac );
    $version = $new_version;
} # end if

my $new_version = 1927;
if ( $version < $new_version ) {
    print "Updating to version $new_version\n";
    my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Products LIMIT 1', {} );
	if ( $data ) {
	$dbh->do('ALTER TABLE Products ADD deleted boolean') if ! exists $$data{'deleted'};
	} # end if
    my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Product_Categories LIMIT 1', {} );
	if ( $data ) {
	$dbh->do('ALTER TABLE Product_Categories ADD deleted boolean') if ! exists $$data{'deleted'};
	} # end if
    sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
    $version = $new_version;
} # end if



my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM sessions LIMIT 1', {} );
if ( ! $data ) {
	my $ac = sql::start_transaction( $dbh );
	$_ = misc::load_file( $log, q{../openprint/sql/Sessions.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
	sql::end_transaction( $dbh, $ac );
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Papers LIMIT 1', {} );
if ( ! exists $$data{'material_id'} ) {
    my $ac = sql::start_transaction( $dbh );
	print "Adding material_id to Papers";
	$dbh->do(q`alter table Papers add material_id INTEGER`);
        $_ = misc::load_file( $log, q{../openprint/sql/StockMaterials.sql});
        foreach my $st ( split(';', $_ ) ) {
            $dbh->do($st);
        }
	$dbh->do(q`insert into stockmaterials (name) values ('Paper')`);
	$dbh->do(q`alter table Papers add foreign key (material_id) REFERENCES Stockmaterials (id)`);
	$dbh->do(q`update Papers set material_id=1`);
    sql::end_transaction( $dbh, $ac );
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Quote_Details LIMIT 1', {} );
my $ac = sql::start_transaction( $dbh );
$dbh->do(q`alter table tbl_Quote_Details add include_detailed boolean default false`) if ! exists $$data{'include_detailed'};
if ( ! exists $$data{'template_id'} ) {
$dbh->do(q`alter table tbl_Quote_Details add template_id INTEGER`);
$dbh->do(q`alter table tbl_Quote_Details add foreign key (template_id) REFERENCES QuoteLevels (id)`);
} # end if
$dbh->do(q`alter table tbl_Quote_Details add id SERIAL NOT NULL`) if ! exists $$data{'id'};
$dbh->do(q`alter table tbl_Quote_Details DROP dblmarkup`) if exists $$data{'dblmarkup'};
sql::end_transaction( $dbh, $ac );

if ( ! openprint::ServiceType::find('name'=>'Paper') ) {
    my $PaperService = new openprint::ServiceType();
    $PaperService->save({'name'=>'Paper',
            'description'=>'Paper',
            'url'=>'',
            'type'=>'Paper',
            'category'=>'Materials',
            'sorting'=>undef,
            'create_visible'=>'N',
            'view_visible'=>'Y',
            });
} # end if
foreach my $E ( openprint::Equipment::find('Specifications'=>{'Type'=>'Press'}) ) {
    foreach my $Spec ( openprint::EquipmentSpecification::find('equipment_id'=>$E->id(), 'name'=>'Press Run Overs Rate') ) {
        $Spec->name('MakeReady Overs Rate');
        $Spec->save();
print "Updating Press RUn Overs Rate to MakeReady Overs Rate\n";
    } # end if
    foreach my $Spec ( openprint::EquipmentSpecification::find('equipment_id'=>$E->id(), 'name'=>'Press Run Overs Minimum') ) {
        $Spec->name('Overs Minimum');
        $Spec->save();
print "Updating Press RUn Overs Rate to MakeReady Overs Minimum\n";
    } # end if
    if ( ! $E->Specification('Sheeter') ) {
        my $Spec = new openprint::EquipmentSpecification();
        $Spec->save({'name'=>'Sheeter','value'=>'Y','equipment_id'=>$E->id()});
        print "Adding Sheeter setting on . " . $E->name() . "\n";
    } # end if
} # end foreach E

if ( ! openprint::MaterialCategory::find('name'=>'PlainCartons') ) {
    my $Category = new openprint::MaterialCategory();
    $Category->save({'name'=>'PlainCartons'});
    print "Adding PlainCartons Category\n";
} # end if

foreach my $M ( openprint::Material::find('name'=>'Plain Carton') ) {
	if ( ! $M->specification('Maximum Weight') ) {
		my $S = new openprint::MaterialSpecification();
		$S->save({
				'material_id'	=>	$M->id(),
				'name'	=>	'Maximum Weight',
				'value'	=>	'40',
				});
	} # end if
	next if $M->Category()->name() eq 'PlainCartons';
	foreach my $C ( openprint::MaterialCategory::find('name'=>'PlainCartons') ) {
		$M->category_id( $C->id() );
		last;
	} # end foreach $C
	$M->save();
} # end foreach $M
if ( ! openprint::MaterialCategory::find('name'=>'BulkSkids') ) {
    my $Category = new openprint::MaterialCategory();
    $Category->save({'name'=>'BulkSkids'});
    print "Adding BulkSkids Category\n";
} # end if

foreach my $M ( openprint::Material::find('name'=>'BulkSkid') ) {
	if ( ! $M->specification('Maximum Weight') ) {
		my $S = new openprint::MaterialSpecification();
		$S->save({
				'material_id'	=>	$M->id(),
				'name'	=>	'Maximum Weight',
				'value'	=>	'1500',
				});
	} # end if
	next if $M->Category()->name() eq 'BulkdSkids';
	foreach my $C ( openprint::MaterialCategory::find('name'=>'BulkSkids') ) {
		$M->category_id( $C->id() );
		last;
	} # end foreach $C
	$M->save();
} # end foreach $M

foreach my $S ( openprint::ServiceType::find('name'=>['SaddleStitching','LoopStitching']) ) {
	if ( $S->type() ne 'Stitching' ) {
		$S->type('Stitching');
		$S->save();
	} # end if
} # end foreach

if ( ! openprint::ServiceType::find('name'=>'Aqueous') ) {
	print "Adding Aqueous ServiceType\n";
	my $S = new openprint::ServiceType();
	$S->save({
		'name'	=>	'Aqueous',
		'description'	=>	'Aqueous',
		'type'		=>	'Aqueous',
		'category'	=>	'Printing',
		'url'		=>	'spec/Aqueous.html',
		'create_visible'	=>	0,
		'view_visible'		=>	1,
});
} # end if

if ( ! openprint::ServiceCategory::find('name'=>'Coating') ) {
	print "Adding Coating Service Category\n";
	my $SC = new openprint::ServiceCategory();
	$SC->save({
		'name'=>'Coating',
	});
} # end if
foreach my $S ( openprint::Service::find('name'=>'Aqueous') ) {
	print "Converting Service Aqueous\n";
	$S->name('Aqueous Gloss Overall');
	$S->description('Aqueous Gloss Overall');
	$S->category('Coating');
	$S->save();
	my $S2 = $S->copy();
	$S2->name('Aqueous Matte Overall');
	$S2->description('Aqueous Matte Overall');
	$S2->save();
	foreach my $P ( $S->prices() ) {
		$P = $P->copy();
		$P->service_id( $S2->id() );
		$P->save();
	} # end foreach
} # end if
foreach my $S ( openprint::Service::find('name'=>'AqueousMakeReady') ) {
	print "Converting Service Aqueous MakeReady\n";
	$S->name('Aqueous Gloss Overall MakeReady');
	$S->description('Aqueous Gloss Overall MakeReady');
	$S->save();
	my $S2 = $S->copy();
	$S2->name('Aqueous Matte Overall MakeReady');
	$S2->description('Aqueous Overall Matte MakeReady');
	$S2->save();
	foreach my $P ( $S->prices() ) {
		$P = $P->copy();
		$P->service_id( $S2->id() );
		$P->save();
	} # end foreach
} # end if
if ( ! openprint::ServiceType::find('name'=>'Varnish') ) {
	my $S = new openprint::ServiceType();
	$S->save({
		'name'	=>	'Varnish',
		'description'	=>	'Varnish',
		'type'		=>	'Varnish',
		'category'	=>	'Printing',
		'url'		=>	'spec/Varnish.html',
		'create_visible'	=>	0,
		'view_visible'		=>	1,
});
} # end if
foreach my $S ( openprint::Service::find('name'=>'VarnishInLine') ) {
	print "Converting VarnishInLine to coatings\n";
	$S->name('Varnish Gloss Overall');
	$S->description('Varnish Gloss Overall');
	$S->category('Coating');
	$S->save();

	my $S2 = $S->copy();
	$S2->name('Varnish Gloss Spot');
	$S2->description('Varnish Gloss Spot');
	$S2->save();
	foreach my $P ( $S->prices() ) {
		$P = $P->copy();
		$P->service_id( $S2->id() );
		$P->save();
	} # end foreach
	$S2 = $S->copy();
	$S2->name('Varnish Matte Overall');
	$S2->description('Varnish Matte Overall');
	$S2->save();
	foreach my $P ( $S->prices() ) {
		$P = $P->copy();
		$P->service_id( $S2->id() );
		$P->save();
	} # end foreach
	$S2 = $S->copy();
	$S2->name('Varnish Matte Spot');
	$S2->description('Varnish Matte Spot');
	$S2->save();
	foreach my $P ( $S->prices() ) {
		$P = $P->copy();
		$P->service_id( $S2->id() );
		$P->save();
	} # end foreach
} # end if
foreach my $S ( openprint::Service::find('name'=>'VarnishMakeReady') ) {
	print "Converting VarnishInLineMake Readies\n";
	$S->name('Varnish Gloss Overall MakeReady');
	$S->description('Varnish Gloss Overall MakeReady');
	$S->save();

	my $S2 = $S->copy();
	$S2->name('Varnish Gloss Spot MakeReady');
	$S2->description('Varnish Gloss Spot MakeReady');
	$S2->save();

	foreach my $P ( $S->prices() ) {
		$P = $P->copy();
		$P->service_id( $S2->id() );
		$P->save();
	} # end foreach

	$S2 = $S->copy();
	$S2->name('Varnish Matte Overall MakeReady');
	$S2->description('Varnish Matte Overall MakeReady');
	$S2->save();
	foreach my $P ( $S->prices() ) {
		$P = $P->copy();
		$P->service_id( $S2->id() );
		$P->save();
	} # end foreach
	$S2 = $S->copy();
	$S2->name('Varnish Matte Spot MakeReady');
	$S2->description('Varnish Matte Spot MakeReady');
	$S2->save();
	foreach my $P ( $S->prices() ) {
		$P = $P->copy();
		$P->service_id( $S2->id() );
		$P->save();
	} # end foreach
}

foreach my $E ( openprint::Equipment::find('Specifications'=>{'Aqueous Coating'=>'Y'}) ) {
	my $S = $E->Specification('Aqueous Coating');
	$S->name('Aqueous Capable');
	$S->save();
} # end foreach E

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM currencies LIMIT 1', {} );
if ( ! exists $$data{'short'} ) {
	$dbh->do('ALTER TABLE Currencies ADD short TEXT');
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Pricelists LIMIT 1', {} );
my $ac = sql::start_transaction( $dbh );
$dbh->do('ALTER TABLE Pricelists RENAME COLUMN currencyindex TO currency_id') if $$data{'currencyindex'};
$dbh->do('ALTER TABLE Pricelists RENAME COLUMN index TO id') if $$data{'index'};
sql::end_transaction( $dbh, $ac );

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM ordered_products LIMIT 1', {} );
if ( $data and ! exists $$data{'project_id'} ) {
print "Adding project_id to ordered_Products\n";
	$dbh->do(q`alter table ordered_products add project_id INTEGER`);
	$dbh->do(q`alter table ordered_products add FOREIGN KEY (project_id) REFERENCES tbl_Projects (index)`);
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM products LIMIT 1', {} );
if ( $data and ! exists $$data{'project_id'} ) {
print "Adding project_id to Products\n";
	$dbh->do(q`alter table products add project_id INTEGER`);
	$dbh->do(q`alter table products add FOREIGN KEY (project_id) REFERENCES tbl_Projects (index)`);
} # end if


sql::insert($log, $dbh, 'configuration', 'name', 'Cached Objects', 'value','usergroup,Material,Service,ServiceType,Equipment,Paper', 'type','text');

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Equipment LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'location_id'} ) {
		$dbh->do('ALTER TABLE tbl_Equipment ADD location_id INTEGER');
		$dbh->do('ALTER TABLE tbl_Equipment ADD FOREIGN KEY (location_id) REFERENCES Locations (id)');
	} # end if
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM survey_question_available_answers LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'id'} ) {
		$dbh->do('ALTER TABLE survey_question_available_answers ADD id SERIAL NOT NULL');
		$dbh->do('ALTER TABLE survey_question_available_answers ADD PRIMARY KEY (id)');
	} # end if
}
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Payments LIMIT 1', {} );
if ( ! $data ) {
		$_ = misc::load_file( $log, q{../openprint/sql/Payments.sql});
		foreach my $st ( split(';', $_ ) ) {
			$dbh->do($st);
		}
} else {
	if ( ! exists $$data{'owner_id'} ) {
		$dbh->do('ALTER TABLE Payments add owner_id INTEGER');
		$dbh->do('ALTER TABLE Payments add FOREIGN KEY (owner_id) REFERENCES Companies (id)');
	} # end if
	if ( exists $$data{'company_id'} ) {
		$dbh->do('ALTER TABLE Payments rename column company_id to payor_id');
		$dbh->do('ALTER TABLE Payments add FOREIGN KEY (payor_id) REFERENCES Companies (id)');
	} # end if
	if ( exists $$data{'curamount'} ) {
		$dbh->do('ALTER TABLE Payments rename column curamount to amount');
	} # end if
	if ( ! exists $$data{'updated_on'} ) {
		$dbh->do('ALTER TABLE Payments add updated_on timestamp with time zone not null default NOW()');
	} # end if
	if ( exists $$data{'dtmdate'} ) {
		$dbh->do('ALTER TABLE Payments rename column dtmdate to date');
	} # end if
	if ( exists $$data{'strmethod'} ) {
		$dbh->do('ALTER TABLE Payments rename column strmethod to method');
	} # end if
	if ( exists $$data{'strtransactionid'} ) {
		$dbh->do('ALTER TABLE Payments rename column strtransactionid to transaction_id');
	} # end if
	if ( exists $$data{'strdescription'} ) {
		$dbh->do('ALTER TABLE Payments rename column strdescription to memo');
	} # end if
	if ( ! exists $$data{'completed'} ) {
		$dbh->do('ALTER TABLE Payments add completed boolean NOT NULL default false;');
	} # end if
	if ( ! exists $$data{'remaining'} ) {
		$dbh->do('ALTER TABLE Payments add remaining float;');
	} # end if
	if ( ! exists $$data{'deleted'} ) {
		$dbh->do('ALTER TABLE Payments add deleted boolean NOT NULL default false;');
	} # end if
} # end if

$dbh->disconnect();
1;
__END__
