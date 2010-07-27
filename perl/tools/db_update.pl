#!/usr/bin/perl
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
configuration::init_cache( $log, $dbh );

my ( $version, $updated_on, $backup ) = sql::execute( undef, undef, q{SELECT version,updated_on, backup FROM database_info ORDER BY updated_on DESC LIMIT 1} );
print "Current Database Version: $version Backups: $backup, Last Updated: $updated_on\n";
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM database_info LIMIT 1', {} );
if ( ! $data ) {
	$_ = misc::load_file( $log, q{../openprint/sql/database_info.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} 

my @tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
my @sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);

if ( ! sets::isin( 'orders', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Orders.sql}) );
}
if ( ! sets::isin( 'quotelevels', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/QuoteLevels.sql}) );
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
	die "Unable to create quotelevels" if ! sets::isin( 'quotelevels', \@tables );
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Project_Types LIMIT 1', {} );
if ( $data ) {
	if ( exists $$data{'lngindex'} ) {
		$dbh->do('ALTER TABLE Project_Types rename column lngindex to id');
		$dbh->do('ALTER TABLE Project_Types rename column strid to name');
		$dbh->do('ALTER TABLE Project_Types rename column strname to description');
		$dbh->do('ALTER TABLE Project_Types rename column strdetailedurl to url');
		$dbh->do('ALTER TABLE Project_Types rename column lngsort to sorting');
		$dbh->do('CREATE SEQUENCE Project_Types_id_seq');
		$dbh->do(q`SELECT setval('project_types_id_seq', (SELECT MAX(id) FROM PRoject_Types))` );
		$dbh->do(q`DROP SEQUENCE IF EXISTS ProjectTypeIndex` );
	} # end if
	if ( exists $$data{'strbasicurl'} ) {
		$dbh->do('ALTER TABLE Project_Types drop strbasicurl');
	}
	if ( exists $$data{'strtemplateurl'} ) {
		$dbh->do('ALTER TABLE Project_Types drop strtemplateurl');
	}
} else {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Project_Types.sql}) );
} # end if

if ( sets::isin( 'tbl_projects', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_projects'", 'column_name');
	if ( $data ) {
		if ( ! exists $$data{'style_id'} ) {
			my $ac = sql::start_transaction( $dbh );
			$dbh->do('ALTER TABLE tbl_Projects ADD style_id INTEGER');
			$dbh->do('ALTER TABLE tbl_Projects ADD FOREIGN KEY (style_id) REFERENCES QuoteLevels (id)');
			sql::end_transaction( $dbh, $ac );
		} # end if
		if ( ! exists $$data{'rush'} ) {
			print "Adding rush to projects";
			$dbh->do(q`alter table tbl_Projects add rush boolean default false`);
		} # end if
		if ( ! exists $$data{'predefined'} ) {
			my $ac = sql::start_transaction( $dbh );
			print "Adding predefined to tbl_Projects\n";
			$dbh->do(q`alter table tbl_Projects add predefined boolean`);
			$dbh->do(q`alter table tbl_Projects alter predefined set default false`);
			$dbh->do(q`update tbl_Projects set predefined=false`);
			$dbh->do(q`alter table tbl_Projects alter predefined set not null`);
			sql::end_transaction( $dbh, $ac );
		} # end if
		$dbh->do(q`ALTER TABLE tbl_Projects rename to Projects`);
	} # end if
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
} # end if
if ( ! sets::isin( 'projects', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Projects.sql}) ) or die;
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='projects'", 'column_name');
	if ( exists $$data{'index'} ) {
		$dbh->do('ALTER TABLE Projects rename column index to id');
		$dbh->do('ALTER TABLE Projects rename column companyindex to company_id');
		$dbh->do('ALTER TABLE Projects rename column userindex to user_id');
	} # end if
	my $ac = sql::start_transaction( $dbh );
	if ( ! exists $$data{'style_id'} ) {
		$dbh->do('ALTER TABLE Projects ADD style_id INTEGER');
		$dbh->do('ALTER TABLE Projects ADD FOREIGN KEY (style_id) REFERENCES QuoteLevels (id)');
	} # end if
	sql::end_transaction( $dbh, $ac );
	if ( ! exists $$data{'rush'} ) {
		my $ac = sql::start_transaction( $dbh );
		print "Adding rush to projects";
		$dbh->do(q`alter table Projects add rush boolean default false`);
		sql::end_transaction( $dbh, $ac );
	} # end if
	if ( ! exists $$data{'summary'} ) {
		$dbh->do(q`alter table Projects add summary text`) or $log->error($dbh->errstr());
	} # end if
} # end if

if ( ! sets::isin( 'tbl_project_contents', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/tbl_Project_Contents.sql' ) ) or die;
}
if ( ! sets::isin( 'tbl_service_specifications', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/tbl_Service_Specifications.sql' ) ) or die;
}
if ( ! sets::isin( 'project_log', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Project_Log.sql' ) ) or die;
}
if ( ! sets::isin( 'barcode_log', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Barcode_Log.sql' ) ) or die;
}
if ( ! sets::isin( 'bindery_schedule', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Bindery_Schedule.sql' ) ) or die;
}
if ( ! sets::isin( 'uploads', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Uploads.sql' ) ) or die;
}
if ( ! sets::isin( 'pressactivities', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/PressActivities.sql' ) ) or die;
}
if ( ! sets::isin( 'project_files', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Project_Files.sql' ) ) or die;
}

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
		$dbh->do(q`alter table Users rename column chrtype to type`);
		sql::end_transaction( $dbh, $ac );
	}
	$dbh->do(q`alter table Users rename column strpassword to password`) if exists $$data{'strpassword'};
	$dbh->do(q{alter table Users drop column ysnHTMLEmails}) if exists $$data{'ysnhtmlemails'};
	$dbh->do(q{alter table Users drop column stremployeetype}) if exists $$data{'stremployeetype'};
	$dbh->do(q{alter table Users drop column strmailserverusername}) if exists $$data{'strmailserverusername'};
	$dbh->do(q{alter table Users drop column strmailserverpassword}) if exists $$data{'strmailserverpassword'};
	$dbh->do(q{alter table Users drop column lastlogin}) if exists $$data{'lastlogin'};
	$dbh->do(q{alter table Users rename column index to id}) if exists $$data{'index'};
	$dbh->do(q`alter table users add deleted boolean`) if ! exists $$data{'deleted'};
	$dbh->do(q`alter table users add email_quotes_to_myself boolean default false`) if ! exists $$data{'email_quotes_to_myself'};
	$dbh->do('ALTER TABLE USERS RENAME COLUMN ysnaccountactivation TO web_active') if exists $$data{'ysnaccountactivation'};
	$dbh->do('ALTER TABLE USERS RENAME COLUMN companyindex TO company_id') if exists $$data{'companyindex'};
	if ( ! exists $$data{'purchasing_limit'} ) {
		$dbh->do(q`alter table Users add purchasing_limit	float`);
	} # end if
	if ( ! exists $$data{'purchasing_total_limit'} ) {
		$dbh->do(q`alter table Users add purchasing_total_limit	float`);
	} # end if
	if ( exists $$data{'usertype'} and ! exists $$data{'type'} ) {
		$dbh->do(q`alter table Users rename column usertype to type`);
	} # end if
	if ( exists $$data{'strcustomgreeting'} ) {
		if ( exists $$data{'greeting'} ) {
		$dbh->do(q`alter table Users DROP column strcustomgreeting`);
		} else {
		$dbh->do(q`alter table Users rename column strcustomgreeting to greeting`);
		} # end if
	}
	$dbh->do(q{alter table users add howdidyouhearaboutusother text}) if ! exists $$data{'howdidyouhearaboutusother'};
	if ( ! exists $$data{quote_level} ) {	
		$dbh->do(q`alter table Users add quote_level integer`);
		$dbh->do(q`alter table Users add foreign key (quote_level) REFERENCES QuoteLevels (id)`);
	} # end if
	if ( ! exists $$data{'notes'} ) {
		$dbh->do('alter table users add notes text');
	} # end if
} # end if
if ( sets::isin( 'users_index_seq', \@sequences ) ) {
	if ( ! sets::isin( 'users_id_seq', \@sequences ) ) {
		$dbh->do('CREATE SEQUENCE users_id_seq');
	} # end if
	$dbh->do("ALTER TABLE Users ALTER id set default nextval('users_id_seq')" );
	$dbh->do('DROP SEQUENCE users_index_seq');
	$dbh->do(q`SELECT setval('users_id_seq', (SELECT max(id) FROM users))` );
	@sequences = sql::execute( undef, undef, q`SELECT sequence_name FROM information_schema.sequences where sequence_schema='public'`);
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
    sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
    sql::end_transaction( $dbh, $ac );
    $version = $new_version;
} # end if

print "Updating Companies\n";
if ( ! sets::isin( 'companies', \@tables ) ) {
	if ( ! sets::isin( 'company', \@tables ) ) {
		$_ = misc::load_file( $log, q{../openprint/sql/Companies.sql});
		foreach my $st ( split(';', $_ ) ) {
			$dbh->do($st);
		} # end foreach
	} else {
		my $ac = sql::start_transaction( $dbh );
		print "Renaming company to companies\n";
		$dbh->do('ALTER TABLE Company RENAME TO Companies');
		my $data2 = $openprint::dbh->selectrow_hashref( 'SELECT * FROM companies LIMIT 1', {} );
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
		$dbh->do(q`alter table Companies rename column ysnmailinglist to mailinglist`);
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
		sql::end_transaction( $dbh, $ac );
	} # end if
} # end if
my $data1 = $openprint::dbh->selectrow_hashref( 'SELECT * FROM companies LIMIT 1', {} );
if ( $data1 ) {
if ( ! exists $$data1{'deleted'} ) {
		$dbh->do(q`ALTER TABLE companies add deleted BOOLEAN default false`);
} # end if
} # end if
my $data = $dbh->selectrow_hashref( 'SELECT * FROM companies LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'notes'} ) {
		$dbh->do('alter table companies add notes text');
	} # end if
	if ( ! exists $$data{'deleted'} ) {
		$log->debug( 'Adding deleted to Companies.' );
		my $ac = sql::start_transaction( $dbh );
		$dbh->do(q`alter table companies add deleted boolean`);
		$dbh->do(q`alter table companies alter deleted set default false`);
		$dbh->do(q`update companies set deleted=false`);
		$dbh->do(q`alter table companies alter deleted set not null`);
		sql::end_transaction( $dbh, $ac );
	} # end if
} else {
	$log->debug( 'No Companies found.' );
} # end if

if ( ! sets::isin( 'todos', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Todos.sql' ) ) or die;
}
if ( ! sets::isin( 'bug_statuses', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Bug_Statuses.sql' ) ) or die;
}
if ( ! sets::isin( 'bugs', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Bugs.sql' ) ) or die;
}
if ( ! sets::isin( 'bug_comments', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Bug_Comments.sql' ) ) or die;
}

if ( ! sets::isin( 'locations', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Locations.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} # end if
my $data;
if ( sets::isin( 'tbl_equipment', \@tables ) ) {
	$data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_equipment'", 'column_name');
	if ( ! $data ) {
		die "No table description?";
	} 
	if ( ! exists $$data{'location_id'} ) {
		$dbh->do('ALTER TABLE tbl_Equipment ADD location_id INTEGER');
		$dbh->do('ALTER TABLE tbl_Equipment ADD FOREIGN KEY (location_id) REFERENCES Locations (id)');
	} # end if
	if ( exists $$data{'lngindex'} ) {
		$dbh->do('ALTER TABLE tbl_Equipment rename  column lngindex to id;');
	} # end if
	$dbh->do('ALTER TABLE tbl_Equipment ADD cip3_in TEXT') if ! exists $$data{'cip3_in'};
	$dbh->do('ALTER TABLE tbl_Equipment ADD cip3_out TEXT') if ! exists $$data{'cip3_out'};
	$dbh->do('ALTER TABLE tbl_Equipment ADD cip3_hold TEXT') if ! exists $$data{'cip3_hold'};
	$dbh->do('ALTER TABLE tbl_Equipment ADD cip3_merge TEXT') if ! exists $$data{'cip3_merge'};
	$dbh->do('ALTER TABLE tbl_Equipment ADD cip3_monitor TEXT') if ! exists $$data{'cip3_monitor'};
	$dbh->do('ALTER TABLE tbl_Equipment ADD smartscheduling BOOLEAN default false') if ! exists $$data{'smartscheduling'};
	if ( ! exists $$data{'jdf_name'} ) {
		$dbh->do(q`alter table tbl_equipment add jdf_name text`);
	} # end if
	if ( ! exists $$data{'jdf_id'} ) {
		$dbh->do(q`alter table tbl_equipment add jdf_id text`);
	} # end if
} else {
    $dbh->do( misc::load_file( $log, q{../openprint/sql/tbl_Equipment.sql} )) or die;
} # end if
if ( ! sets::isin( 'tbl_equipment_specifications' ) ) {
	my $sql = misc::load_file( $log, q{../openprint/sql/tbl_Equipment_Specifications.sql}) or die "Can't load tbl_Equipment_Specifications.sql";
	$dbh->do($sql);
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='tbl_equipment_specifications'", 'column_name' );
	if ( $data ) {
		if ( exists $$data{'lngindex'} ) {
			$dbh->do('ALTER TABLE tbl_Equipment_SPecifications rename column lngindex to id');
			$dbh->do('CREATE SEQUENCE tbl_equipment_specifications_id_seq');
			$dbh->do("ALTER TABLE tbl_Equipment_specifications alter column id set default nextval('tbl_equipment_specifications_id_seq')");
			$dbh->do('DROP SEQUENCE EquipmentSpecification_seq');
			$dbh->do("SELECT setval('tbl_equipment_specifications_id_seq', (SELECT MAX(id) FROM tbl_equipment_specifications) )");
		} # end if
	} # end if
} # end if

	
if ( ! sets::isin( 'papers', \@tables ) ) {
	$dbh->do(misc::load_file( $log, '../openprint/sql/Papers.sql') );
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='papers'", 'column_name');
	if ( ! exists $$data{'bladecleaning'} ) {
		$dbh->do('alter table papers add bladecleaning boolean');
		sql::update( undef, undef, 'papers', 'bladecleaning IS NULL', 'bladecleaning', 'false' );
    } # end if
	if ( ! exists $$data{'grain_direction'} ) {
		$dbh->do('alter table papers add grain_direction text');
		sql::update( undef, undef, 'papers', 'width > height', 'grain_direction', 'Short' );
		sql::update( undef, undef, 'papers', 'width < height', 'grain_direction', 'Long' );
	} # end if
} # end if
if ( ! sets::isin( 'paper_allocations', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Paper_Allocations.sql' ) ) or die;
}
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
	sql::insert( undef, undef, 'database_info', 'version', 1291, 'backup', $backup );
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
	sql::insert( undef, undef, 'database_info', 'version', 1381, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1381;
	
}
if ( ! sets::isin( 'skids', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Skids.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM skids LIMIT 1', {} );
	if ( $data ) {
		if ( ! exists $$data{'type'} ) {
			$dbh->do('alter table skids add type text');
			$dbh->do('alter table skids add deleted boolean not null default false');
		} # end if
		if ( ! exists $$data{'updated_on'} ) {
			$dbh->do(q{alter table skids add updated_on timestamp with time zone default NOW()});
			$dbh->do(q{update skids set updated_on=NOW()});
		} # endif
		if ( ! exists $$data{'updated_by'} ) {
			$dbh->do(q{alter table skids add updated_by INTEGER});
			$dbh->do(q{update skids set updated_by=created_by_id});
			$dbh->do(q{alter table skids alter updated_by SET NOT NULL});
			$dbh->do(q{alter table skids ADD FOREIGN KEY (updated_by) REFERENCES Users (id)});
		} # endif
	} # end if
} # end if 1456

if ( sets::isin( 'tbl_service_types', \@tables ) ) {
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
	$dbh->do(q`ALTER TABLE service_types ADD type TEXT`);
	$dbh->do(q`UPDATE service_types SET type=name WHERE type IS NULL`);
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
	if ( ! sets::isin('service_types_id_seq', \@sequences) ) {
		$dbh->do(q{CREATE SEQUENCE service_types_id_seq});
		$dbh->do(q{select setval('service_types_id_seq', (SELECT Max(id) FROM service_types) )});
	} # end if
	$dbh->do(q{ALTER TABLE service_types alter id set default nextval('service_types_is_seq')});
} # end if
if ( ! sets::isin( 'servicetype_categories', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/ServiceType_Categories.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
	foreach my $c ( sql::execute( undef, undef, 'SELECT DISTINCT category FROM Service_types' ) ) {
		sql::insert( undef, undef, 'servicetype_categories', 'name', $c );
	} # end foreach
} # end if
	new openprint::ServiceType_Category()->save({'name'=>'Printing','sorting'=>1}) if ! openprint::ServiceType_Category->find('name'=>'Printing');
	new openprint::ServiceType_Category()->save({'name'=>'Coatings','sorting'=>2}) if ! openprint::ServiceType_Category->find('name'=>'Coatings');
	new openprint::ServiceType_Category()->save({'name'=>'Prepress','sorting'=>3}) if ! openprint::ServiceType_Category->find('name'=>'Prepress');
	new openprint::ServiceType_Category()->save({'name'=>'Bindery','sorting'=>4}) if ! openprint::ServiceType_Category->find('name'=>'Bindery');
	new openprint::ServiceType_Category()->save({'name'=>'Specialty','sorting'=>5}) if ! openprint::ServiceType_Category->find('name'=>'Specialty');
	new openprint::ServiceType_Category()->save({'name'=>'Packaging','sorting'=>6}) if ! openprint::ServiceType_Category->find('name'=>'Packaging');
	new openprint::ServiceType_Category()->save({'name'=>'Shipping','sorting'=>7}) if ! openprint::ServiceType_Category->find('name'=>'Shipping');
	new openprint::ServiceType_Category()->save({'name'=>'Materials','sorting'=>8}) if ! openprint::ServiceType_Category->find('name'=>'Materials');
	new openprint::ServiceType_Category()->save({'name'=>'Custom Services','sorting'=>10}) if ! openprint::ServiceType_Category->find('name'=>'Custom Services');

	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Printing','sorting'=>undef ) ) {
		$STC->save({'sorting'=>1}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Prepress','sorting'=>undef ) ) {
		$STC->save({'sorting'=>3}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Bindery','sorting'=>undef ) ) {
		$STC->save({'sorting'=>4}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Specialty','sorting'=>undef ) ) {
		$STC->save({'sorting'=>5}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Packaging','sorting'=>undef ) ) {
		$STC->save({'sorting'=>6}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Shipping','sorting'=>undef ) ) {
		$STC->save({'sorting'=>7}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Materials','sorting'=>undef ) ) {
		$STC->save({'sorting'=>8}) if ! $STC->sorting();
	} # end if
	if ( my $STC = openprint::ServiceType_Category->find_one( 'name'=>'Custom Services','sorting'=>undef ) ) {
		$STC->save({'sorting'=>10}) if ! $STC->sorting();
	} # end if

my $data;
if ( sets::isin( 'service_types', \@tables ) ) {
	$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Service_types LIMIT 1', {} );
} # end if
if ( $data ) {
	if ( ! exists $$data{'type'} ) {
		$dbh->do(q`ALTER TABLE service_types ADD type TEXT`);
	} # end if
	$dbh->do(q`UPDATE service_types SET type=name WHERE type IS NULL`);
	if ( exists $$data{'category'} ) {
		if ( ! exists $$data{'category_id'} ) {
		$dbh->do(q`ALTER TABLE service_types add category_id INTEGER`);
		$dbh->do('UPDATE service_types set category_id=(select id from servicetype_categories where name=category)');
		} # end if
		$dbh->do('ALTER TABLE service_types DROP COLUMN category');
	}# end if
} else {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Service_Types.sql}) ) or die;
}
if ( ! sets::isin( 'service_categories_id_seq', \@sequences ) ) {
	$dbh->do('create sequence service_categories_id_seq;');
	$dbh->do(q`alter table service_categories alter id set default nextval('service_categories_id_seq')`);
	$dbh->do(q`select setval('service_categories_id_seq', (select max(id) from service_categories) )`);
	$dbh->do(q`drop sequence servicecategoriesindex_seq`) if sets::isin( 'servicecategoriesindex_seq', \@sequences );
} # en dif

if ( ! sets::isin( 'tbl_service_defaults', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/tbl_Service_Defaults.sql}) ) or die;
}

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
	sql::insert( undef, undef, 'database_info', 'version', 1586, 'backup', $backup );
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
	sql::insert( undef, undef, 'database_info', 'version', 1587, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1587;
} # end if

if ( sets::isin( 'tbl_services', \@tables ) ) {
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
	@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
} # end if

if ( sets::isin( 'services', \@tables ) ) {
	my $data = $dbh->selectrow_hashref( 'SELECT * FROM Services LIMIT 1', {} );
	if ( ! $data ) {
	} else {
		if ( sets::isin( 'serviceindex_seq', \@sequences ) ) {
			$dbh->do('DROP SEQUENCE serviceindex_seq');
			$dbh->do('CREATE SEQUENCE services_id_seq');
			$dbh->do("ALTER TABLE Services alter column id set default nextval('services_id_seq')");
			$dbh->do("SELECT setval('services_id_seq', (SELECT MAX(id) FROM Services))");
		} # end if
		if ( ! exists $$data{'owner_id'} ) {
			$dbh->do('ALTER TABLE Services add owner_id INTEGER');
			$dbh->do('ALTER TABLE Services add FOREIGN KEY(owner_id) REFERENCES companies (id)');
		} # end if
	} # end if
} else {
	$_ = misc::load_file( $log, q{../openprint/sql/Services.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} # end if

if ( sets::isin( 'tbl_service_categories', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Service_Categories LIMIT 1', {} );
	if ( $data ) {
		my $ac = sql::start_transaction( $dbh );
		$dbh->do(q{alter table tbl_Service_Categories rename column lngindex to id});
		$dbh->do(q{alter table tbl_Service_Categories rename column strid to name});
		$dbh->do(q{alter table tbl_Service_Categories drop column strname});
		$dbh->do(q{alter table tbl_Service_Categories rename to Service_Categories});
		$dbh->do(q{update Services set category_id=NULL where category_id NOT IN (SELECT id FROM Service_Categories)});
		$dbh->do(q{ALTER TABLE Services ADD foreign key (category_id) REFERENCES Service_Categories (id)});
		sql::end_transaction( $dbh, $ac );
		@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
	} # end if
} # end if
if ( ! sets::isin( 'service_categories', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Service_Categories.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} # end if

sql::insert(undef,undef,'configuration', [
    'name','UseCaptchaOnRegistration',
    'value','N',
    'type','yes/no',
    'description','Use a CAPTCHA on the registration to protect against automated bots.',
    'category','Captcha Settings'] ) if ! $config{'UseCaptchaOnRegistration'};
sql::insert(undef,undef,'configuration', [
    'name','RegistrationCaptchaLength',
    'value','3',
    'type','text',
    'description','Number of characters in the CAPTCHA on the registration page.',
    'category', 'Captcha Settings'] ) if ! $config{'RegistrationCaptchaLength'};
sql::insert(undef,undef,'configuration', [
    'name','UnitPriceFormat',
    'value','%.2f',
    'type','text',
    'description','Format String for unit prices.',
    'category', 'Miscellaneous Settings'] ) if ! $config{'UnitPriceFormat'};
sql::insert(undef,undef,'configuration', [
    'name','DefaultPricelist',
    'type','pricelist',
    'description','Default Pricelist.',
    'category', 'Miscellaneous Settings',
    'value',undef,
] ) if ! exists $config{'DefaultPricelist'};
sql::insert(undef,undef,'configuration', [
    'name','AcceptCreditApplications',
    'type','yes/no',
    'description','Whether to show links to a credit application page.',
    'category', 'Miscellaneous Settings',
    'value',undef,
] ) if ! exists $config{'AcceptCreditApplications'};

sql::insert(undef,undef,'configuration', [
    'name','PerfectBindCoverGutter',
    'value',0.125,
    'type','text',
    'description', 'The amount of space to add to each edge on the height of the cover.',
    'category', 'Perfect Binding Settings',
] ) if ! $config{'PerfectBindCoverGutter'};

sql::insert(undef,undef,'configuration', [
    'name','PerfectBindGlueSpace',
    'value',0.03125,
    'type','text',
    'description','The amount of space to add to the width of the cover to account for the glue.',
    'category', 'Perfect Binding Settings',
    ] ) if ! $config{'PerfectBindGlueSpace'};

if ( $config{'public_URIs'} ) {
	my @paths = split(',', $config{'public_URIs'} );
	for ( my $p=0; $p < @paths; $p +=1 ) {
		if ( $paths[$p] =~ /confirmation_login/ ) {
			$paths[$p] = '/index.html';
		#} elsif ( $paths[$p] =~ /login_confirmation/ ) {
			#$paths[$p] = '/index.html';
		} elsif ( $paths[$p] =~ /overview/ ) {
			$paths[$p] = '/index.html';
		} elsif ( $paths[$p] =~ /search/ ) {
			$paths[$p] = '/index.html';
		} elsif ( $paths[$p] =~ /main(\/account.*)/ ) {
			$paths[$p] = $1;
		} elsif ( $paths[$p] =~ /\.\*(\/account.*)/ ) {
			$paths[$p] = $1;
		}
	} # end foreach
	push @paths, '/main/project/_calc.json' if ! sets::isin( '/main/project/_calc.json', \@paths );
	sql::update( undef, undef, 'configuration', ['name=?', 'public_URIs'], 'value', join(',',sets::union(@paths)) );
} # end inf
if ( $config{cookie_issue_URIs} ) {
sql::execute( undef, undef, 'delete from configuration where name=?', 'cookie_issue_URIs' );
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
	sql::insert( undef, undef, 'database_info', 'version', 1898, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1898;
} # end if
if ( $version < 1899 ) {
	print "Updating to version 1899\n";
	#$dbh->do(q{alter table skid_contents add primary key (skid_id, paper_id)});
	#my $ac = sql::start_transaction( $dbh );
	#$dbh->do(q{drop index if exists "skid_contents_skid_id_index"});
	#sql::insert( undef, undef, 'database_info', 'version', 1899, 'backup', $backup );
	#sql::end_transaction( $dbh, $ac );
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
if ( sets::isin( 'tbl_service_prices', \@tables ) ) {
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
		@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);
	} # end if
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Service_Prices LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'owner_id'} ) {
		$dbh->do('ALTER TABLE Service_Prices ADD owner_id INTEGER');
		$dbh->do('ALTER TABLE Service_Prices ADD FOREIGN KEY (owner_id) REFERENCES Companies(id)');
	} # end if
	if ( ! exists $$data{'supplier_id'} ) {
		$dbh->do('ALTER TABLE Service_Prices ADD supplier_id INTEGER');
		$dbh->do('ALTER TABLE Service_Prices ADD FOREIGN KEY (supplier_id) REFERENCES Companies(id)');
	} # end if
} # end if
if ( $version < 1901 ) {
	print "Updating to version 1901\n";
	my $ac = sql::start_transaction( $dbh );
	my @Services = openprint::Service->find('name'=>'PressUnitMakeReady');
	push @Services, openprint::Service->find('name'=>'PressUnitMakeReadySheet Work');
	if ( @Services ) {
		my $Service = $Services[0];
		foreach my $Equipment ( openprint::Equipment->find('category'=>'Printing') ) {
			foreach my $Price ( openprint::ServicePrice->find('Equipment'=>$Equipment, 'Service'=>$Service )) {
				if ( $$Price{'units'} eq 'Per Unit' ) {
					$$Price{'cost'} = $$Price{'cost'}/$$Price{'min'};
					$$Price{'price'} = $$Price{'price'}/$$Price{'min'};
					$Price->save();
				} # end if
			} # end foreach
		} # end foreach
	} # en dif
	sql::insert( undef, undef, 'database_info', 'version', 1901, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1901;
} # end if

if ( ! sets::isin( 'folds', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Folds.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='folds'", 'column_name' );
	if ( $data ) {
		$dbh->do('alter table folds add cutting boolean') if ! exists $$data{'cutting'};
		$dbh->do('alter table folds add printing_type text') if ! exists $$data{'printing_type'};
		$dbh->do(q`alter table folds add folds integer`) if ( ! exists $$data{'folds'} );
		$dbh->do(q`alter table folds add angles integer`) if ( ! exists $$data{'angles'} );
	} # end if
} # end if


foreach my $E ( openprint::Equipment->find('Specifications'=>{'Cutting Capable'=>'Y','Stitching Capable'=>'Y'}) ) {
	foreach my $Spec ( $E->Specifications() ) {
		if ( $Spec->name() =~ /Cutting Capable/ ) {
			$Spec->value('When Stitching');
			$Spec->save();
		} # end if
	} # end foreach
}
foreach my $E ( openprint::Equipment->find('Specifications'=>{'Folding Capable'=>['For Pocket Folders','Y']}) ) {
	foreach my $Spec ( $E->Specifications() ) {
		if ( $Spec->name() =~ /^(\d+)PageSignatureFoldRunSpeed$/ ) {
			my $pages = $1;
			my $Fold = new openprint::Fold();
			$Fold->equipment_id( $E->id() );
			$Fold->name( $pages.'PageFold' );
			$Fold->type( $pages . 'PageFold' );
			$Fold->pages( $pages );
			$Fold->max_imposition( 2 );
			$Fold->stitching( 1 );
			$Fold->perfectbind( 1 );
			if ( $_ = $E->Specification($pages.'PageSignatureFoldPrintingType') ) {
				$Fold->printing_type( $_->value() );
				$_->delete();
			} # end if
			if ( $_ = $E->Specification($pages.'PageSignatureFoldOvers') ) {
				$Fold->makeready_overs( $_->value() );
				$Fold->makeready_overs_units( $_->units() );
				$_->delete();
			} # end if
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
			$Fold->max_imposition( 2 );
			$Fold->stitching( 1 );
			$Fold->perfectbind( 1 );
			if ( $_ = $E->Specification($type.'FoldPrintingType') ) {
				$Fold->printing_type( $_->value() );
				$_->delete();
			} # end if
			if ( $_ = $E->Specification($type.'FoldOvers') ) {
				$Fold->makeready_overs( $_->value() );
				$Fold->makeready_overs_units( $_->units() );
				$_->delete();
			} # end if
			$_ = $Fold->save();
			die $_ if $_;
			my $FS = new openprint::FoldSpecification();
			$FS->fold_id( $Fold->id() );
			$FS->runspeed( $Spec->value() );
			$FS->interpolate( $Spec->interpolate() );
			$_ =  $FS->save();
			die $_ if $_;
			$Spec->delete();
		} elsif ( $Spec->name() =~ /^(\d+)Panel(\d+)Pocket(\w*)RunSpeed/ ) {
			my ($panel, $pocket, $gusset ) = ( $1, $2, $3 );
			my $Fold = new openprint::Fold();
			$Fold->equipment_id( $E->id() );
			$Fold->name( $panel.'Panel'.$pocket.'Pocket'.$gusset );
			$Fold->type( $panel.'Panel'.$pocket.'Pocket'.$gusset );
			$Fold->max_imposition( 1 );
			$_ = $Fold->save();
			die $_ if $_;
			my $FS = new openprint::FoldSpecification();
			$FS->fold_id( $Fold->id() );
			$FS->runspeed( $Spec->value() );
			$FS->interpolate( $Spec->interpolate() );
			$_ =  $FS->save();
			die $_ if $_;
			$Spec->delete();
			if ( ! openprint::Service->find('name'=>$panel.'Panel'.$pocket.'Pocket'.$gusset) ) {
				my $Service = new openprint::Service();
				$Service->save({
					'name'=>$panel.'Panel'.$pocket.'Pocket'.$gusset,
					'description'=>$panel.'Panel'.$pocket.'Pocket'.$gusset,
					'category'=>'Bindery',
				});
			}
		}
	}  # end foreach Spec
	foreach my $Spec ( $E->Specifications() ) {
		my $found = 0;
		if ( $Spec->name() =~ /^Runspeed Adjustment$/ ) {
			$found = 1;
			foreach my $Fold ( openprint::Fold->find('equipment_id'=>$E->id()) ) {
				foreach my $FoldSpec ( $Fold->Specifications() ) {
					if ( ! ( $FoldSpec->min_weight() or $FoldSpec->max_weight() ) ) {
						my $FoldSpec2 = $FoldSpec->copy();
						$FoldSpec2->save({
							'runspeed'=>$FoldSpec->runspeed() - ( $FoldSpec->runspeed()*($Spec->value()/100) ),
							'min_weight'=>$Spec->min(), 
							'max_weight'=>$Spec->max(),
							'interpolate'	=>	$Spec->interpolate(),
						});
					} # end if
				} # end foreach FoldSpec
			} # end foreach
			$Spec->delete();
		} # end if Spec->name
		if ($found) {
			foreach my $Fold ( openprint::Fold->find('equipment_id'=>$E->id()) ) {
				foreach my $FoldSpec ( $Fold->Specifications() ) {
					if ( ! ( $FoldSpec->min_weight() or $FoldSpec->max_weight() ) ) {
						$FoldSpec->delete();
					} # endif
			} # end foreachd
			} # end foreachd
		} # end if found
	}  # end foreach Spec
}


my $FoldingService;
my @FoldingServices = openprint::Service->find('name'=>'Folding');
if ( ! @FoldingServices ) {
	$FoldingService = new openprint::Service();
	$FoldingService->save({
		'name'	=>	'Folding',
		'description'	=>	'Folding',
});
} else {
	$FoldingService = $FoldingServices[0];
} # en dif
	
foreach my $E ( openprint::Equipment->find('category'=>'Printing') ) {
	foreach my $Spec ( $E->Specifications('name'=>'Envelope Ready') ) {
		$Spec->name('Envelope Capable');
		$Spec->save();
	} 
	foreach my $Spec ( $E->Specifications('name'=>'Default Bleed Size') ) {
		if ( $Spec->max() == 1 ) {
			$Spec->max('');
		} elsif ( $Spec->min() == 2 ) {
			$Spec->name('Default Bleed SizeMultiPagePublication');
			$Spec->min('');
		} # end if
		$_ = $Spec->save();
		$log->error($_) if $_;
	} # end foreach
} # end foreach
foreach my $E ( openprint::Equipment->find('Specifications'=>{'Folding Capable'=>'When Printing'}) ) {
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
				if ( $spine_direction eq 'Vertical' ) {
					$Fold->min_width( sprintf( '%.3f', ($_->value()/$columns)) );
				} else {
					$Fold->min_height( sprintf( '%.3f', ($_->value()/$columns)) );
				} # end if
				$_->delete();
			} #end if
			if ( $_ = $E->Specification( $fold.'MaximumWidth' ) ) {
				if ( $spine_direction eq 'Vertical' ) {
					$Fold->max_width( sprintf('%.3f', ($_->value()/$columns)) );
				} else {
					$Fold->max_height( sprintf('%.3f', ($_->value()/$columns)) );
				} # end if
				$_->delete();
			} # en dif
			if ( $_ = $E->Specification( $fold.'MinimumHeight' ) ) {
				if ( $spine_direction eq 'Vertical' ) {
				$Fold->min_height( sprintf('%.3f', ($_->value()/$rows)) );
				} else {
				$Fold->min_width( sprintf('%.3f', ($_->value()/$columns)) );
				} # end if
				$_->delete();
			} # end if
			if ( $_ = $E->Specification( $fold.'MaximumHeight' ) ) {
				if ( $spine_direction eq 'Vertical' ) {
				$Fold->max_height( sprintf('%.3f', ($_->value()/$rows)) );
				} else {
				$Fold->max_width( sprintf('%.3f', ($_->value()/$columns)) );
				} # end if
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
	} # end foreach Spec
	if ( ! openprint::ServicePrice->find('service_id'=>$FoldingService->id(), 'equipment_id'=>$E->id() ) ) {
		foreach my $Pricelist ( openprint::Pricelist->find() ) {
if ( ! $Pricelist->id() ) {
print "ERror pricelits: " . $Pricelist->name() . "\n";
} else {
			my $ServicePrice = new openprint::ServicePrice();
			$ServicePrice->save({
				'service_id'	=>	$FoldingService->id(),
				'pricelist_id'	=>	$Pricelist->id(),
				'equipment_id'	=>	$E->id(),
				'units'			=>	'Per M',
				'cost'			=>	0,
				'price'			=>	0,
				});
}
		} # end foreach Pricelist
	} # end if
} # end foreach Web Press
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

if ( ! sets::isin( 'material_categories', \@tables ) ) {
	$dbh->do( misc::load_file( $log, q{../openprint/sql/Material_Categories.sql}) ) or die;
} else {

	$dbh->do(q{alter table material_categories alter column id drop default});
	if ( sets::isin('materialcategoriesindex_seq', \@sequences ) ) {
		$dbh->do('drop sequence materialcategoriesindex_seq') 
	} 
	if ( ! sets::isin('material_categories_id_seq', \@sequences ) ) {
		$dbh->do('create sequence material_categories_id_seq');
	}
	$dbh->do(q{select setval('material_categories_id_seq', (select max(id) from material_categories))});
	$dbh->do(q{alter table material_categories alter column id set default nextval('material_categories_id_seq')});
}


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

foreach my $E ( openprint::Equipment->find() ) {
	foreach my $Fold ( openprint::Fold->find('equipment_id'=>$E->id()) ) {
		if ( $Fold->type() =~ /(\d*)PageSignatureFold/ ) {
			$Fold->type( "$1PageFold" );
			$Fold->save();
		} # end if
	} # end foreach
} # end foreach

foreach my $E ( openprint::Equipment->find() ) {
	foreach my $Fold ( openprint::Fold->find('equipment_id'=>$E->id()) ) {
		if ( $Fold->type() =~ /(\d*)PageFold/ ) {
			sql::update( undef, undef, 'Services', ['name=?', "$1PageSignatureFold"], 'name', "$1PageFold" );
			sql::update( undef, undef, 'Services', ['name=?', "$1PageSignatureFoldMakeReady"], 'name', "$1PageFoldMakeReady" );
		} # end if
	} # end foreach
} # end foreach

if ( ! sets::isin( 'manifests', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Manifests.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Manifests LIMIT 1', {} );
	if ( $data ) {
		my $ac = sql::start_transaction( $dbh );
		if ( ! exists $$data{'po_id'} ) {
			$dbh->do('ALTER TABLE Manifests add po_id INTEGER');
			$dbh->do('ALTER TABLE Manifests add FOREIGN KEY (po_id) REFERENCES PurchaseOrders (id)');
		} # end if
		if ( ! exists $$data{'supplier_id'} ) {
			$dbh->do('ALTER TABLE Manifests add supplier_id INTEGER');
			$dbh->do('ALTER TABLE Manifests add FOREIGN KEY (supplier_id) REFERENCES Companies (id)');
		} # end if
		if ( ! exists $$data{'docket'} ) {
			$dbh->do('ALTER TABLE Manifests add docket INTEGER');
		} # end if
		if ( ! exists $$data{'delivered_on_switch'} ) {
			$dbh->do('ALTER TABLE Manifests add delivered_on_switch TEXT');
		} # end if
		if ( ! exists $$data{'vendor_sms'} ) {
			$dbh->do('ALTER TABLE Manifests add vendor_sms TEXT');
		} # end if
		if ( ! exists $$data{'shipto_sms'} ) {
			$dbh->do('ALTER TABLE Manifests add shipto_sms TEXT');
		} # end if
		sql::end_transaction( $dbh, $ac );
	} # end if
} # end if

if ( ! sets::isin( 'purchaseorders', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/PurchaseOrders.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} else {
	my $data = $dbh->selectrow_hashref( 'SELECT * FROM purchaseorders LIMIT 1', {} );
	if ( $data ) {
		my $ac = sql::start_transaction( $dbh );
		if ( ! exists $$data{'federaltax_charge'} ) {
			$dbh->do('ALTER TABLE purchaseorders add federaltax_charge BOOLEAN');
		} # end if
		if ( ! exists $$data{'statetax_charge'} ) {
			$dbh->do('ALTER TABLE purchaseorders add statetax_charge BOOLEAN');
		} # end if
		if ( ! exists $$data{'cancelled'} ) {
			$dbh->do('ALTER TABLE purchaseorders add cancelled BOOLEAN');
			$dbh->do('ALTER TABLE purchaseorders alter cancelled set default false');
			$dbh->do('UPDATE purchaseorders set cancelled=false');
			$dbh->do('ALTER TABLE purchaseorders alter cancelled set not null');
		} # end if
		if ( ! exists $$data{'authorized'} ) {
			$dbh->do('ALTER TABLE purchaseorders add authorized BOOLEAN');
			$dbh->do('UPDATE purchaseorder set authorized=true WHERE authorized_on IS NOT NULL');
		} # end if
		if ( ! exists $$data{'manifest_id'} ) {
			$dbh->do('ALTER TABLE purchaseorders add manifest_id TEXT');
			$dbh->do('ALTER TABLE purchaseorders add FOREIGN KEY (manifest_id) REFERENCES Manifests (id)');
		} # end if
		sql::end_transaction( $dbh, $ac );
	} # end if
} # end if
if ( ! sets::isin( 'purchaseorder_contenttypes', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/PurchaseOrder_ContentTypes.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
}
if ( ! sets::isin( 'purchaseorder_contents', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/PurchaseOrder_Contents.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # en dif


foreach my $Type ( openprint::ServiceType->find('name'=>'BulkSkids') ) {
    $Type->type( 'Skids' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'PlainCartons') ) {
    $Type->type( 'Skids' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'Bundling') ) {
    $Type->type( 'Packaging' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'ShrinkWrap') ) {
    $Type->type( 'Packaging' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'KraftWrap') ) {
    $Type->type( 'Packaging' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'ColourCorrection') ) {
    $Type->type( 'Prepress' );
    $Type->save();
}
foreach my $Type ( openprint::ServiceType->find('name'=>'CDBurning') ) {
    $Type->type( 'Prepress' );
    $Type->save();
}

if ( ! sets::isin( 'stockgroups', \@tables ) ) {
	my $ac = sql::start_transaction( $dbh );
	$_ = misc::load_file( $log, q{../openprint/sql/StockGroups.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
	sql::end_transaction( $dbh, $ac );
} # end if


my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Papers LIMIT 1', {} );
if ( ! $data ) {
} else {
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
	$dbh->do(q{alter table papers add minimum_order integer}) if ! exists $$data{'minimum_order'};
	$dbh->do(q{alter table papers add inventory_number	text}) if ! exists $$data{'inventory_number'};
	$dbh->do(q{alter table papers add full_packages boolean}) if ! exists $$data{'full_packages'};
	if ( exists $$data{'req_die_scoring'} ) {
		$dbh->do(q{alter table papers rename column req_die_scoring to diescoring});
	} else {
		$dbh->do(q{alter table papers add diescoring boolean}) if ! exists $$data{'diescoring'};
	}
	if ( ! exists $$data{'group_id'} ) {
		$dbh->do(q`ALTER TABLE papers ADD group_id INTEGER`);
		$dbh->do(q`ALTER TABLE papers ADD FOREIGN KEY (group_id) REFERENCES StockGroups (id)`);
	} # end if
	if ( ! exists $$data{'message'} ) {
		$dbh->do(q`alter table papers add message text`);
	} # end if
	if ( ! exists $$data{'in_stock'} ) {
		$dbh->do(q`alter table papers add in_stock integer`);
	} # end if
	if ( ! exists $$data{'parts'} ) {
		$dbh->do(q`alter table papers add parts integer`);
	} # end if
} # end if

if ( ! sets::isin( 'rfidtags', \@tables ) ) {
	my $ac = sql::start_transaction( $dbh );
	$_ = misc::load_file( $log, q{../openprint/sql/RFID.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
	sql::end_transaction( $dbh, $ac );
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM skids LIMIT 1', {} );
if ( $data and ! exists $$data{'rfidtag_id'} ) {
	$dbh->do(q`alter table skids add rfidtag_id TEXT`);
	$dbh->do(q`alter table skids add FOREIGN KEY (rfidtag_id) REFERENCES RFIDTags (id)`);
} # end if

if ( ! sets::isin( 'user_service_defaults', \@tables ) ) {
	my $ac = sql::start_transaction( $dbh );
	$_ = misc::load_file( $log, q{../openprint/sql/User_Service_Defaults.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
	sql::end_transaction( $dbh, $ac );
} # end if


if ( sets::isin( 'projecttype_categories', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM projecttype_categories LIMIT 1', {} );
	if ( $data and ! exists $$data{'sort'} ) {
		$dbh->do('ALTER TABLE projecttype_categories ADD sort integer');
	} # end if
} else {
	$_ = misc::load_file( $log, q{../openprint/sql/ProjectType_Categories.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} # end if
if ( ! sets::isin( 'product_categories', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Product_Categories.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Product_Categories LIMIT 1', {} );
	$dbh->do('ALTER TABLE Product_Categories ADD deleted boolean') if $data and ! exists $$data{'deleted'};
} # end if

if ( ! sets::isin( 'products', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Products.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Products LIMIT 1', {} );
	$dbh->do('ALTER TABLE Products ADD deleted boolean') if $data and ! exists $$data{'deleted'};
} # end if

if ( ! sets::isin( 'product_specifications', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Product_Specifications.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM sessions LIMIT 1', {} );
if ( ! $data ) {
	my $ac = sql::start_transaction( $dbh );
	$_ = misc::load_file( $log, q{../openprint/sql/Sessions.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
	sql::end_transaction( $dbh, $ac );
} else {
	if ( ! exists $$data{'a_session'} ) {
		$dbh->do('ALTER TABLE sessions add a_session TEXT');
	}
	if ( ! exists $$data{'id'} ) {
		$dbh->do('ALTER TABLE sessions add id TEXT');
		$dbh->do('ALTER TABLE sessions add PRIMARY KEY (id)');
	}
} # end if



my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Quote_Details LIMIT 1', {} );
if ( $data ) {
	my $ac = sql::start_transaction( $dbh );
	$dbh->do(q`alter table tbl_Quote_Details add include_detailed boolean default false`) if ! exists $$data{'include_detailed'};
	if ( ! exists $$data{'template_id'} ) {
	$dbh->do(q`alter table tbl_Quote_Details add template_id INTEGER`);
	$dbh->do(q`alter table tbl_Quote_Details add foreign key (template_id) REFERENCES QuoteLevels (id)`);
	} # end if
	$dbh->do(q`alter table tbl_Quote_Details add id SERIAL NOT NULL`) if ! exists $$data{'id'};
	$dbh->do(q`alter table tbl_Quote_Details DROP dblmarkup`) if exists $$data{'dblmarkup'};
	sql::end_transaction( $dbh, $ac );
} # end if
$log->debug("Materials");
new openprint::ServiceType_Category()->save({'name'=>'Materials','sorting'=>8}) if ! openprint::ServiceType_Category->find('name'=>'Materials');
if ( my $ServiceType = openprint::ServiceType->find_one('name'=>'Paper') ) {
	$ServiceType->save({'category'=>'Materials'}) if $ServiceType->category() ne 'Materials';
} else {
	my $PaperService = new openprint::ServiceType();
    $PaperService->save({'name'=>'Paper',
            'description'=>'Paper',
            'url'=>'Paper.html',
            'type'=>'Paper',
            'category'=>'Materials',
            'sorting'=>undef,
            'create_visible'=>'N',
            'view_visible'=>'Y',
            });
} # end if
foreach my $E ( openprint::Equipment->find('Specifications'=>{'Type'=>'Press'}) ) {
    foreach my $Spec ( openprint::EquipmentSpecification->find('equipment_id'=>$E->id(), 'name'=>'Press Run Overs Rate') ) {
        $Spec->name('MakeReady Overs Rate');
        $Spec->save();
print "Updating Press RUn Overs Rate to MakeReady Overs Rate\n";
    } # end if
    foreach my $Spec ( openprint::EquipmentSpecification->find('equipment_id'=>$E->id(), 'name'=>'Press Run Overs Minimum') ) {
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

if ( my @C = openprint::MaterialCategory->find('name'=>'Plain Cartons') ) {
	foreach ( @C ) {
		$_->save({'name'=>'PlainCartons'});
	}
} elsif ( ! openprint::MaterialCategory->find('name'=>'PlainCartons') ) {
    my $Category = new openprint::MaterialCategory();
    $Category->save({'name'=>'PlainCartons'});
    print "Adding PlainCartons Category\n";
} # end if

foreach my $M ( openprint::Material->find('name_like'=>'Plain Carton%') ) {
	if ( my ( $w, $h, $d ) = $M->name() =~ /Plain Carton (\d+)x(\d+)x(\d+)/ ) {
		if ( $d and ! $M->specification('Depth') ) {
			my $S = new openprint::MaterialSpecification();
			$S->save({
				'material_id'	=>	$M->id(),
				'name'			=>	'Depth',
				'value'			=>	$d,
			});
		} # endif
		if ( $w and ! $M->specification('Width') ) {
			my $S = new openprint::MaterialSpecification();
			$S->save({
				'material_id'	=>	$M->id(),
				'name'			=>	'Depth',
				'value'			=>	$w,
			});
		} # end if
		if ( $h and ! $M->specification('Height') ) {
			my $S = new openprint::MaterialSpecification();
			$S->save({
				'material_id'	=>	$M->id(),
				'name'			=>	'Height',
				'value'			=>	$h,
			});
		} # end if
	} # end if
	if ( ! $M->specification('Maximum Weight') ) {
		my $S = new openprint::MaterialSpecification();
		$S->save({
				'material_id'	=>	$M->id(),
				'name'	=>	'Maximum Weight',
				'value'	=>	'40',
				});
	} # end if
	next if $M->Category()->name() eq 'PlainCartons';
	foreach my $C ( openprint::MaterialCategory->find('name'=>'PlainCartons') ) {
		$M->category_id( $C->id() );
		last;
	} # end foreach $C
	$M->save();
} # end foreach $M
if ( ! openprint::MaterialCategory->find('name'=>'BulkSkids') ) {
    my $Category = new openprint::MaterialCategory();
    $Category->save({'name'=>'BulkSkids'});
    print "Adding BulkSkids Category\n";
} # end if

if ( my $M = openprint::Material->find_one('name'=>'BulkSkids') ) {
	if ( ! openprint::Material->find('name'=>'BulkSkid') ) {
		$M->save({'name'=>'BulkSkid'});
	} 
}
foreach my $M ( openprint::Material->find('name'=>'BulkSkid') ) {
	if ( ! $M->specification('Maximum Weight') ) {
		my $S = new openprint::MaterialSpecification();
		$S->save({
				'material_id'	=>	$M->id(),
				'name'	=>	'Maximum Weight',
				'value'	=>	'1500',
				});
	} # end if
	if ( ! $M->specification('Depth') ) {
		my $S = new openprint::MaterialSpecification();
		$S->save({
			'material_id'	=>	$M->id(),
			'name'			=>	'Depth',
			'value'			=>	56,
		});
	} # endif
	next if $M->Category()->name() eq 'BulkSkids';
	foreach my $C ( openprint::MaterialCategory->find('name'=>'BulkSkids') ) {
		$M->category_id( $C->id() );
		last;
	} # end foreach $C
	$M->save();
} # end foreach $M

foreach my $S ( openprint::ServiceType->find('name'=>['SaddleStitching','LoopStitching']) ) {
	if ( $S->type() ne 'Stitching' ) {
		$S->type('Stitching');
		$S->save();
	} # end if
} # end foreach

new openprint::ServiceType_Category()->save({'name'=>'Coatings','sorting'=>2}) if ! openprint::ServiceType_Category->find('name'=>'Coatings');
if ( my $S = openprint::ServiceType->find_one('name'=>'Aqueous') ) {
	$S->save({'category'=>'Coatings'}) if $S->category() ne 'Coatings';
} else {
	print "Adding Aqueous ServiceType\n";
	my $S = new openprint::ServiceType();
	$S->save({
		'name'	=>	'Aqueous',
		'description'	=>	'Aqueous',
		'type'		=>	'Aqueous',
		'category'	=>	'Coatings',
		'url'		=>	'spec/Aqueous.html',
		'create_visible'	=>	0,
		'view_visible'		=>	1,
});
} # end if

foreach my $ST ( openprint::ServiceType->find('name'=>'DieCutting') ) {
	$_ = $ST->save({'url'=>'bind/DieCutting.html'}) if $ST->url() ne 'bind/DieCutting.html';
	die $_ if $_;
}

if ( ! openprint::ServiceCategory->find('name'=>'Coating') ) {
	print "Adding Coating Service Category\n";
	my $SC = new openprint::ServiceCategory();
	$SC->save({
		'name'=>'Coating',
	});
} # end if
if ( ! openprint::Service->find('name'=>'Perforating') ) {
	if ( my @S = openprint::Service->find('name'=>'Perforation') ) {
		foreach my $S ( @S ) {
			$S->save({'name'=>'Perforating'});
		}
	} # end if
	if ( my @S = openprint::Service->find('name'=>'PerforationMakeReady') ) {
		foreach my $S ( @S ) {
			$S->save({'name'=>'PerforatingMakeReady'});
		}
	} # end if
}
if ( ! openprint::Material->find('name'=>'PerforatingWheel') ) {
	if ( my @M = openprint::Material->find('name'=>'PerforatingRule') ) {
		foreach my $M ( @M ) {
			my $New = $M->copy();
			$New->save({'name'=>'PerforatingWheel'});
			foreach my $P ( $M->prices() ) {
				$P=$P->copy();
				$P->save({'material_id'=>$New->id()});
			} # end foreach
		} # end foreach $M
	} # en d if
} # end if

foreach my $S ( openprint::Service->find('name'=>'Aqueous') ) {
	if ( ! openprint::Service->find('name'=>'Aqueous Gloss Overall') ) {
		print "Converting Service Aqueous\n";
		my $S2 = $S->copy();
		$S2->name('Aqueous Gloss Overall');
		$S2->description('Aqueous Gloss Overall');
		$S2->category('Coating');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->units('per 1000 impressions');
			$P->save();
		} # end foreach
	} # end if
	if ( ! openprint::Service->find('name'=>'Aqueous Gloss Spot') ) {
		print "Converting Service Aqueous\n";
		my $S2 = $S->copy();
		$S2->name('Aqueous Gloss Spot');
		$S2->description('Aqueous Gloss Spot');
		$S2->category('Coating');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->units('per 1000 impressions');
			$P->save();
		} # end foreach
	} # end if
	if ( ! openprint::Service->find('name'=>'Aqueous Matte Overall') ) {
		my $S2 = $S->copy();
		$S2->name('Aqueous Matte Overall');
		$S2->description('Aqueous Matte Overall');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->units('per 1000 impressions');
			$P->save();
		} # end foreach
	} # end if
	if ( ! openprint::Service->find('name'=>'Aqueous Matte Spot') ) {
		my $S2 = $S->copy();
		$S2->name('Aqueous Matte Spot');
		$S2->description('Aqueous Matte Spot');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->units('per 1000 impressions');
			$P->save();
		} # end foreach
	} # end if
	$S->delete();
} # end if
foreach my $S ( openprint::Service->find('name'=>'AqueousMakeReady') ) {
	if ( ! openprint::Service->find('name'=>'Aqueous Gloss Overall MakeReady') ) {
		print "Converting Service Aqueous MakeReady\n";
		$S->name('Aqueous Gloss Overall MakeReady');
		$S->description('Aqueous Gloss Overall MakeReady');
		$S->save();
	} # en dif
	if ( ! openprint::Service->find('name'=>'Aqueous Matte Overall MakeReady') ) {
		my $S2 = $S->copy();
		$S2->name('Aqueous Matte Overall MakeReady');
		$S2->description('Aqueous Overall Matte MakeReady');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->units('per 1000 impressions');
			$P->save();
		} # end foreach
	} # en dif
} # end if
if ( ! openprint::ServiceType->find('name'=>'Varnish') ) {
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
foreach my $S ( openprint::Service->find('name'=>'VarnishInLine') ) {
	print "Converting VarnishInLine to coatings\n";
	if ( ! openprint::Service->find('name'=>'Varnish Gloss Overall') ) {
		$S->name('Varnish Gloss Overall');
		$S->description('Varnish Gloss Overall');
		$S->category('Coating');
		$S->save();
	} # end if

	if ( ! openprint::Service->find('name'=>'Varnish Gloss Spot') ) {
		my $S2 = $S->copy();
		$S2->name('Varnish Gloss Spot');
		$S2->description('Varnish Gloss Spot');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
	} # end if
	if ( ! openprint::Service->find('name'=>'Varnish Matte Overall') ) {
		my $S2 = $S->copy();
		$S2->name('Varnish Matte Overall');
		$S2->description('Varnish Matte Overall');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
	} # en dif
	if ( ! openprint::Service->find('name'=>'Varnish Matte Spot') ) {
		my $S2 = $S->copy();
		$S2->name('Varnish Matte Spot');
		$S2->description('Varnish Matte Spot');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
	} # end if
} # end if
foreach my $S ( openprint::Service->find('name'=>'VarnishMakeReady') ) {
	if ( ! openprint::Service->find('name'=>'Varnish Gloss Overall MakeReady') ) {
		print "Converting VarnishInLineMake Readies\n";
		$S->name('Varnish Gloss Overall MakeReady');
		$S->description('Varnish Gloss Overall MakeReady');
		$S->save();
	} # en dif

	if ( ! openprint::Service->find('name'=>'Varnish Gloss Spot MakeReady') ) {
		my $S2 = $S->copy();
		$S2->name('Varnish Gloss Spot MakeReady');
		$S2->description('Varnish Gloss Spot MakeReady');
		$S2->save();

		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
	} # end if

	if ( ! openprint::Service->find('name'=>'Varnish Matte Overall MakeReady') ) {
		my $S2 = $S->copy();
		$S2->name('Varnish Matte Overall MakeReady');
		$S2->description('Varnish Matte Overall MakeReady');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
	} # en dif
	if ( ! openprint::Service->find('name'=>'Varnish Matte Spot MakeReady') ) {
		my $S2 = $S->copy();
		$S2->name('Varnish Matte Spot MakeReady');
		$S2->description('Varnish Matte Spot MakeReady');
		$S2->save();
		foreach my $P ( $S->prices() ) {
			$P = $P->copy();
			$P->service_id( $S2->id() );
			$P->save();
		} # end foreach
	} # en dif
}

foreach my $E ( openprint::Equipment->find('Specifications'=>{'Aqueous Coating'=>'Y'}) ) {
	my $S = $E->Specification('Aqueous Coating');
	$S->name('Aqueous Capable');
	$S->save();
} # end foreach E

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM currencies LIMIT 1', {} );
if ( ! $data ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Currencies.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} else {
	if ( ! exists $$data{'short'} ) {
		$dbh->do('ALTER TABLE Currencies ADD short TEXT');
	} # end if
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Pricelists LIMIT 1', {} );
my $ac = sql::start_transaction( $dbh );
$dbh->do('ALTER TABLE Pricelists RENAME COLUMN currencyindex TO currency_id') if $$data{'currencyindex'};
$dbh->do('ALTER TABLE Pricelists RENAME COLUMN index TO id') if $$data{'index'};
$dbh->do('ALTER TABLE Pricelists ADD owner_id INTEGER') if ! exists $$data{'owner_id'};
$dbh->do('ALTER TABLE Pricelists ADD deleted BOOLEAN NOT NULL default false') if ! exists $$data{'deleted'};
$dbh->do('ALTER TABLE Pricelists ADD FOREIGN KEY (owner_id) REFERENCES Companies (id)');
if ( sets::isin( 'price_lists_id_seq', \@sequences )   ) {
$dbh->do('DROP SEQUENCE IF EXISTS price_lists_id_seq');
} 
if ( ! sets::isin( 'pricelists_id_seq', \@sequences ) ) {
$dbh->do('CREATE SEQUENCE pricelists_id_seq');
$dbh->do(q`SELECT setval('pricelists_id_seq', (SELECT MAX(id) FROM Pricelists))`);
$dbh->do(q`ALTER TABLE pricelists alter id set default nextval('pricelists_id_seq')`);
} # end if
sql::end_transaction( $dbh, $ac );

if ( sets::isin( 'ordered_products', \@tables ) ) {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='ordered_products'", 'column_name');
	if ( $data and ! exists $$data{'project_id'} ) {
		$dbh->do('ALTER TABLE Ordered_Products add project_id integer');
		$dbh->do('ALTER TABLE Ordered_Products add foreign key (project_id) references projects (id)');
	} # end if
} else {
	$_ = misc::load_file( $log, q{../openprint/sql/Ordered_Products.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
}
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM products LIMIT 1', {} );
if ( $data and ! exists $$data{'project_id'} ) {
print "Adding project_id to Products\n";
	$dbh->do(q`alter table products add project_id INTEGER`);
	$dbh->do(q`alter table products add FOREIGN KEY (project_id) REFERENCES Projects (id)`);
} # end if
my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Projects LIMIT 1', {} );
if ( $data and ! exists $$data{'predefined'} ) {
print "Adding predefined to Projects\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do(q`alter table Projects add predefined boolean`);
	$dbh->do(q`alter table Projects alter predefined set default false`);
	$dbh->do(q`update Projects set predefined=false`);
	$dbh->do(q`alter table Projects alter predefined set not null`);
	sql::end_transaction( $dbh, $ac );
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM RFIDScanners LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'monitor'} ) {
		$dbh->do('ALTER TABLE RFIDScanners ADD monitor boolean not null default false');
	} # end if
} # end if

sql::insert($log, $dbh, 'configuration', 'name', 'Cached Objects', 'value','usergroup,Material,Service,ServiceType,Equipment,Paper', 'type','text') if ! $config{'Cached Objects'};



my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM survey_question_available_answers LIMIT 1', {} );
if ( $data ) {
	if ( ! exists $$data{'id'} ) {
		$dbh->do('ALTER TABLE survey_question_available_answers ADD id SERIAL NOT NULL');
		$dbh->do('ALTER TABLE survey_question_available_answers ADD PRIMARY KEY (id)');
	} # end if
}

if ( ! sets::isin( 'paymenttypes', \@tables ) ) {
	my $ac = sql::start_transaction( $dbh );
	$_ = misc::load_file( $log, q{../openprint/sql/PaymentTypes.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
	sql::end_transaction( $dbh, $ac );
} else {
} # end if

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
	if ( $data and ! exists $$data{'type_id'} ) {
		$dbh->do('ALTER TABLE payments add type_id INTEGER');
		$dbh->do('ALTER TABLE payments add FOREIGN KEY (type_id) REFERENCES PaymentTypes (id)');
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
foreach my $ServiceType ( openprint::ServiceType->find() ) {
	if ( $ServiceType->name() eq 'PerfectBound' ) {
		$ServiceType->type('PerfectBound') if ( $ServiceType->type() ne 'PerfectBound' );
		if ( $ServiceType->url() ne 'bind/PerfectBound.html' ) {
			$ServiceType->url('bind/PerfectBound.html');
			$log->warn('URL: ' . $ServiceType->url() );
		} # end if
		$ServiceType->save();
	} # end if
} # end foreach ServiceType

if ( ! sets::isin( 'emailcampaigns', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/EmailCampaigns.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} 
if ( ! sets::isin( 'emailtemplates', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/EmailTemplates.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} 
if ( ! sets::isin( 'surveys', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Surveys.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} 

if ( ! sets::isin( 'paper_inventory', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Paper_Inventory.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM paper_inventory LIMIT 1', {} );
	if ( $data ) {
		$dbh->do(q{alter table paper_inventory rename column updatetime to updated_on}) if exists $$data{'updatetime'};
		if ( ! exists $$data{'id'} ) {
			my $ac = sql::start_transaction( $dbh );
			$dbh->do(q{alter table paper_inventory add id integer});
			$dbh->do(q{create sequence paperinventory_id_seq});
			$dbh->do(q{alter table paper_inventory alter id set default nextval('paperinventory_id_seq')});
			$dbh->do(q{update paper_inventory set id=nextval('paperinventory_id_seq')});
			$dbh->do(q{alter table paper_inventory alter id set not null});
			$dbh->do(q{alter table paper_inventory add primary key(id)});
			sql::end_transaction( $dbh, $ac );
		} # end if
		if ( ! exists $$data{'docket'} ) {
			$dbh->do('alter table paper_inventory add docket integer');
		} # end if
	} # end if
	#foreach my $PI ( openprint::PaperInventory->find('docket'=>undef) ) {
		#$PI->save() if $PI->docket();
	#} # end foreach
} # end if

if ( ! sets::isin( 'taxes', \@tables ) ) {
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Taxes LIMIT 1', {} );
	if ( $data ) {
		if ( exists $$data{'dblfederalpercent'} ) {
			$dbh->do( 'ALTER TABLE Taxes rename column dblfederalpercent to federaltax' );
		} # end if
		if ( exists $$data{'dblstatepercent'} ) {
			$dbh->do( 'ALTER TABLE Taxes rename column dblstatepercent to statetax' );
		} # end if
		if ( exists $$data{'dblharmonisedpercent'} ) {
			$dbh->do( 'ALTER TABLE Taxes rename column dblharmonisedpercent to harmonizedtax' );
		} # end if
		if ( ! exists $$data{'id'} ) {
			$dbh->do( 'ALTER TABLE Taxes add id SERIAL' );
			( $_ ) = sql::execute( undef, undef, "SELECT EXISTS ( SELECT * FROM information_schema.table_constraints WHERE constraint_name='taxes_pkey' AND table_name='taxes' ) " );
			if ( $_ ) {
				$dbh->do( 'ALTER TABLE Taxes DROP Constraint taxes_pkey');
			} # end if
			$dbh->do( 'ALTER TABLE Taxes add PRIMARY KEY(id)' );
		} # end if
	} # end if
}
if ( ! sets::isin( 'invoices', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Invoices.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} # end if
if ( ! sets::isin( 'invoiced_products', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Invoiced_Products.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Invoiced_Products LIMIT 1', {} );
	if ( $data and ! exists $$data{'description'} ) {
		$dbh->do('ALTER TABLE Invoiced_Products add description text');
	} # end if
} # end if

if ( ! sets::isin( 'manifest_content_types', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Manifest_Content_Types.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	}
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM manifestcontents LIMIT 1', {} );
	if ( $data ) {
		if ( ! exists $$data{'type_id'} ) {
			require openprint::Manifest;
			$dbh->do('alter table manifestcontents add type_id integer');
			foreach my $Manifest ( openprint::Manifest->find() ) {
				my @Contents = $Manifest->Contents();

				if ( @Contents ) {
					my $T = new openprint::Manifest_Content_Type();
					$_ = $T->save({
						'manifest_id'	=>	$Manifest->id(),
						'docket'		=>	$Contents[0]->docket(),
						'po_id'			=>	$Manifest->po_id(),
					});
					die $_ if $_;
					foreach my $C ( @Contents ) {
						$C->save({'type_id'=>$T->id()});
					} # end foreach
				} # end if
			} # end foreach Manifest
			$dbh->do('alter table manifestcontents alter type_id set not null');
			$dbh->do('alter table manifestcontents add foreign key (type_id) references manifest_content_types (id)');
		} # end if
		if ( ! exists $$data{'docket'} ) {
			$dbh->do('alter table manifestcontents add docket integer');
		} # end if
	} # end if
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM manifest_content_types LIMIT 1', {} );
	if ( $data and ! exists $$data{'supplier_invoice'} ) {
		$dbh->do('alter table manifest_content_types add supplier_invoice text');
	} # end if
} 

foreach my $Currency ( openprint::Currency->find('short'=>'CDN') ) {
$Currency->save({'short'=>'CAD'});
}# end foreach Currency

	if ( ! $config{'TechSupportEmail'} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'TechSupportEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send technical support requests to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{'AdministratorEmail'} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'AdministratorEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address of the person in charge of the website.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{'AccountingEmail'} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'AccountingEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address of the person in charge of accounting.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{'QuotingEmail'} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'QuotingEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send quotes to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{'UserRegistrationEmail'} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'UserRegistrationEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send new user registrations to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{'CreditApplicationEmail'} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'CreditApplicationEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send new credit applications to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{'ResellerApplicationEmail'} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'ResellerApplicationEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send new reseller applications to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{'HelpdeskEmail'} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'HelpdeskEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send helpdesk requests to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{'RMAEmail'} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'RMAEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send RMA requests to.',
				'category'=> 'Email Notifications'] );
	} # end if
	if ( ! $config{'InventoryEmail'} ) {
		sql::insert(undef,undef,'configuration', [
				'name'=>'InventoryEmail',
				'value'=>'"Isaac Connor" <iconnor@connortechnology.com>',
				'type'=>'text',
				'description'=>'Email address to send Inventory notifications to.',
				'category'=> 'Email Notifications'] );
	} # end if
if ( ! sets::isin( 'productionfeedback', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/ProductionFeedback.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
if ( ! sets::isin( 'cip3_ppf', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/CIP3_PPF.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

if ( ! sets::isin( 'employeenumbers', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/EmployeeNumbers.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM EmployeeNumbers LIMIT 1', {} );
	if ( $data ) {
		if ( exists $$data{'lngemployeeid'} ) {
			$dbh->do('alter table employeenumbers rename column lngemployeeid to id');
			$dbh->do('alter table employeenumbers rename column lngmin to min');
			$dbh->do('alter table employeenumbers rename column lngmax to max');
		} # end if
	} # end if
} # end if

if ( ! sets::isin( 'schedule', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Schedule.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} else {
	my $data = $openprint::dbh->selectall_hashref( "SELECT column_name, data_type, column_default, is_nullable FROM information_schema.columns WHERE table_name='schedule'", 'column_name');
	if ( $data ) {
		if ( ! exists $$data{'id'} ) {
			$dbh->do('ALTER TABLE Schedule ADD id SERIAL');
		} # end if
		if ( exists $$data{'serviceindex'} and ! exists $$data{'service_id'} ) {
			$dbh->do('ALTER TABLE Schedule ADD service_id INTEGER[]');
			$dbh->do('UPDATE Schedule SET service_id=ARRAY[serviceindex]');
#$dbh->do('ALTER TABLE Schedule DROP serviceindex');
		} # end if
		if ( ! exists $$data{'starttime_locked'} ) {
			$dbh->do('ALTER TABLE Schedule ADD starttime_locked boolean');
		} # end if
	} # end if
	$dbh->do('ALTER TABLE Schedule ADD speed INTEGER') if ! exists $$data{'speed'};
} # end if

if ( ! sets::isin( 'labels', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Labels.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

if ( sets::isin('shifts',\@tables) and ! sets::isin( 'equipment_shifts', \@tables ) ) {
	$dbh->do( 'ALTER TABLE Shifts rename to Equipment_Shifts' );
} elsif ( ! sets::isin( 'equipment_shifts', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Equipment_Shifts.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Equipment_Shifts LIMIT 1', {} );
if ( $data and ! exists $$data{'id'} ) {
	$dbh->do('ALTER TABLE Equipment_Shifts drop constraint shifts_pkey');
	$dbh->do('ALTER TABLE Equipment_shifts add id serial');
	$dbh->do('ALTER TABLE Equipment_shifts add PRIMARY KEY (id)');
} # end if

@tables = sql::execute( undef, undef, q`SELECT table_name FROM information_schema.tables where table_schema='public'`);

if ( ! sets::isin('shifts',\@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Shifts.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

if ( sets::isin( 'tbl_quotes', \@tables ) ) {
	$dbh->do('ALTER TABLE tbl_Quotes rename to Quotes');
	$dbh->do('ALTER TABLE Quotes rename column index to id');
	$dbh->do('ALTER TABLE tbl_Quote_Users_For rename column quoteindex to quote_id');
	$dbh->do('ALTER TABLE tbl_Quote_Users_By rename column quoteindex to quote_id');
	$dbh->do('ALTER TABLE tbl_Quote_Details rename column quoteindex to quote_id');
	$dbh->do('ALTER TABLE tbl_Quote_Details rename column projectindex to project_id');
	$dbh->do('DROP SEQUENCE IF EXISTS quotes_id_seq');
	$dbh->do('CREATE SEQUENCE quotes_id_seq');
	$dbh->do("SELECT setval('quotes_id_seq', (select MAX(id) FROM Quotes) )");
	$dbh->do("ALTER TABLE Quotes alter column id set default nextval('quotes_id_seq')");
	push @tables, 'quotes';
} # end if

if ( sets::isin( 'quotes', \@tables ) ) {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM quotes LIMIT 1', {} );
	if ( $data ) {
		$dbh->do('ALTER TABLE quotes DROP column strsessionid') if ( exists $$data{'strsessionid'} );
		if ( ! exists $$data{'currency_id'} ) {
			$dbh->do('ALTER TABLE quotes add currency_id INTEGER');
			$dbh->do('ALTER TABLE quotes add FOREIGN KEY (currency_id) REFERENCES Currencies (id)');
			$dbh->do('UPDATE TABLE Quotes set currency_id = (SELECT id FROM currencies where name=strcurrencyname)');
		} # end if
		$dbh->do('ALTER TABLE quotes DROP column strcurrencyname') if ( exists $$data{'strcurrencyname'} );
		$dbh->do('ALTER TABLE quotes DROP column strcurrencysymbol') if ( exists $$data{'strcurrencysymbol'} );
	} # end if
} # end if

if ( ! sets::isin('articles',\@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Articles.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
if ( ! sets::isin('user_notifications',\@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/User_Notifications.sql});
	foreach my $st ( split(';', $_ ) ) { $dbh->do($st); } # end foreach
} # end if

if ( ! sets::isin( 'claims', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Claims.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
if ( ! sets::isin( 'claim_contenttypes', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Claim_ContentTypes.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
if ( ! sets::isin( 'claim_contents', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Claim_Contents.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if

if ( $version < 1907 ) {
	print "Updating to version 1907\n";
	my $ac = sql::start_transaction( $dbh );
foreach my $E ( openprint::Equipment->find('Specifications'=>{'Type'=>'Press'}) ) {
	print "Looking for Feed on " . $E->strid();
	my $Spec = $E->Specification('Feed');
	if ( ! $Spec ) {
		print "No Feed found, adding it.\n";
		$Spec = new openprint::EquipmentSpecification();
		$Spec->equipment_id( $E->id() );
		$Spec->name( 'Feed' );
		$Spec->value('Sheet');
		print $Spec->save();
	} elsif ( $Spec->value() eq 'Web' ) {
		print "Web found, converting to Roll.\n";
		$Spec->value('Roll');
		print $Spec->save();
	} # end if
	print "no change.\n";
} # end foreach
	sql::insert( undef, undef, 'database_info', 'version', 1907, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1907;
} # end if
if ( $version < 1908 ) {
	print "Updating to version 1908\n";
	my $ac = sql::start_transaction( $dbh );
	sql::insert( undef, undef, 'configuration', { 'name'=>'ProjectViewDisclaimer','value'=>'','type'=>'text','description'=>'Text to display at the bottom of the project view page', 'category'=>'Disclaimers'} ) if ! $config{'ProjectViewDisclaimer'};
	sql::insert( undef, undef, 'configuration', { 'name'=>'OrderViewDisclaimer','value'=>'','type'=>'text','description'=>'Text to display at the bottom of the order view page', 'category'=>'Disclaimers'}) if ! $config{'OrderViewDisclaimer'};
	sql::insert( undef, undef, 'configuration', { 'name'=>'QuoteViewDisclaimer','value'=>'','type'=>'text','description'=>'Text to display at the bottom of the quote view page', 'category'=>'Disclaimers'}) if ! $config{'QuoteViewDisclaimer'};

	sql::insert( undef, undef, 'database_info', 'version', 1908, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1908;
} # end if
if ( $version < 1910 ) {
	print "Updating to version 1910\n";
	my $ac = sql::start_transaction( $dbh );
	$dbh->do('alter table service_types add unique(name);');
	sql::insert( undef, undef, 'database_info', 'version', 1910, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1910;
} # end if
if ( $version < 1914 ) {
	print "Updating to version 1914\n";
	my $ac = sql::start_transaction( $dbh );
	sql::update( undef, undef, 'service_types',['strdetailedurl=?','bind/padding.html'], 'strdetailedurl', 'bind/Padding.html' );
	sql::insert( undef, undef, 'database_info', 'version', 1914, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1914;
} # end if
my $new_version = 1921;
if ( $version < $new_version ) {
	print "Updating to version $new_version\n";
	my $ac = sql::start_transaction( $dbh );
	sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
	foreach my $E ( openprint::Equipment->find() ) {
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

if ( ! sets::isin( 'paper_prices', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Paper_Prices.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
foreach my $PP ( openprint::PaperPrice->find('units'=>'Per M') ) {
	$PP->Cost( sprintf('%.2f', $PP->Cost() * 100 / $PP->Paper()->mweight() ) );
	$PP->Price( sprintf('%.2f', $PP->Price() * 100 / $PP->Paper()->mweight() ) );
	$PP->Units('Per 100lbs');
	$PP->save();
}
if ( ! sets::isin( 'companies_accountingcontacts', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Companies_AccountingContacts.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
if ( ! sets::isin( 'order_id_seq', \@sequences ) ) {
	$dbh->do('create sequence order_id_seq');
	$dbh->do(q`select setval('order_id_seq', (select max(index) from orders) )`);
	$dbh->do(q`alter table orders alter column index set default nextval('order_id_seq');`);
}
if ( ! sets::isin( 'order_contents', \@tables ) ) {
	$dbh->do( misc::load_file( $log, '../openprint/sql/Order_Contents.sql' ) ) or die;
}

if ( my $PaddingServiceType = openprint::ServiceType->find_one('name'=>'Padding') ) {
	sql::update( undef, undef, 'tbl_service_defaults', ['lngservicetypeindex=? AND strfieldname=? AND strdefaultvalue=?',
			$PaddingServiceType->id(), 'rdbCardboardBacking','Y'], [ 'strfieldname', 'Backing', 'strdefaultvalue', 'Cardboard' ] );
	sql::update( undef, undef, 'tbl_service_defaults', ['lngservicetypeindex=? AND strfieldname=? AND strdefaultvalue=?',
			$PaddingServiceType->id(), 'rdbCardboardBacking','N'], [ 'strfieldname', 'Backing', 'strdefaultvalue', 'None']  );
} # end if
if ( ! sets::isin( 'tbl_projecttype_defaults', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/tbl_ProjectType_Defaults.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
sql::update( undef, undef, 'tbl_Projecttype_defaults', ['strfieldname=? AND strdefaultvalue=?','rdbCardboardBacking','Y'], [ 'strfieldname', 'Backing', 'strdefaultvalue', 'Cardboard' ] );
sql::update( undef, undef, 'tbl_Projecttype_defaults', ['strfieldname=? AND strdefaultvalue=?','rdbCardboardBacking','N'], [ 'strfieldname', 'Backing', 'strdefaultvalue', 'None']  );

foreach my $PT ( openprint::ProjectType->find() ) {
	if ( $PT->name() =~ / / ) {
		$_ = $PT->name();
		$_ =~ s/ //g;
		$PT->name( $_ );
		$PT->save();
	} # end if
} # end foreach
if ( ! sets::isin( 'blacklist', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/blacklist.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} # end if
if ( ! sets::isin( 'whitelist', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/whitelist.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
$dbh->do(q{insert into whitelist (ip) values ('68.179.115.209')} );
$dbh->do(q{insert into whitelist (ip) values ('68.179.115.210')} );
$dbh->do(q{insert into whitelist (ip) values ('68.179.115.211')} );
$dbh->do(q{insert into whitelist (ip) values ('68.179.115.212')} );
$dbh->do(q{insert into whitelist (ip) values ('208.89.51.122')} );
} # end if
if ( ! sets::isin( 'hosts', \@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/hosts.sql});
	foreach my $st ( split(';', $_ ) ) {
		$dbh->do($st);
	} # end foreach
} 
if ( ! sets::isin('log',\@tables ) ) {
	$_ = misc::load_file( $log, q{../openprint/sql/Logs.sql});
	foreach my $st ( split(';', $_ ) ) { $dbh->do($st); } # end foreach
} else {
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Log LIMIT 1', {} );
	if ( $data ) {
		if ( ! exists $$data{'host_id'} ) {
			$dbh->do('ALTER TABLE Log add host_id INTEGER');
			$dbh->do('ALTER TABLE Log add FOREIGN KEY (host_id) REFERENCES Hosts (id)');
		} # end if
	} # end if
} # end if
if ( 0 and ! openprint::Host->find_one() ) {
	foreach my $Log ( openprint::Log->find('host_id'=>undef) ) {
		my $data = $openprint::dbh->selectrow_hashref( "SELECT * FROM Log WHERE id=$$Log{id}", {} );
		next if ! $$data{'ip_address'};
		my $Host = openprint::Host->find_one('ip'=>$$data{'ip_address'});
		if ( ! $Host ) {
			$Host = new openprint::Host();
			$Host->save({'ip'=>$$data{'ip_address'},'hostname'=>$$data{'hostname'}});
		} # end if
		$Log->save({'host_id'=>$Host->id()}) if $Host->id();
		die if $dbh->errstr();
	} # end foreach Log
} # end if
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Log LIMIT 1', {} );
	if ( $data ) {
		$dbh->do('ALTER TABLE Log DROP COLUMN ip_address') if ( exists $$data{'ip_address'} );
		$dbh->do('ALTER TABLE Log DROP COLUMN hostname') if ( exists $$data{'hostname'} );
	} # end if
	$dbh->commit();
foreach my $Service ( openprint::Service->find('name'=>'1ColourImpressionPerfecting') ) {
	$_ = $Service->save({'name'=>'PerfectingImpression1/1'});
	print $_ if $_;
} # end foreach Service
foreach my $Service ( openprint::Service->find('name'=>'2ColourImpressionPerfecting') ) {
	$_ = $Service->save({'name'=>'PerfectingImpression2/2'});
	print $_ if $_;
} # end foreach Service
foreach my $Service ( openprint::Service->find('name'=>'3ColourImpressionPerfecting') ) {
	$_ = $Service->save({'name'=>'PerfectingImpression3/3'});
	print $_ if $_;
} # end foreach Service
foreach my $Service ( openprint::Service->find('name'=>'4ColourImpressionPerfecting') ) {
	$_ = $Service->save({'name'=>'PerfectingImpression4/4'});
	print $_ if $_;
} # end foreach Service
if ( sets::isin('product_id_seq', \@sequences ) ) {
	$dbh->do('ALTER SEQUENCE product_id_seq RENAME TO products_id_seq');
}

	$dbh->commit();
$dbh->disconnect();
print "Finished\n";
1;
__END__
