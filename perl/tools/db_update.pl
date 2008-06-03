#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
use strict;

require sql;
require logger;
require openprint::Object;
require openprint::Paper;
require openprint::Equipment;
require openprint::ServicePrice;
require openprint::Service;
require openprint::Project;
require openprint::service;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
$openprint::Object::no_cache = 1;

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

	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Materials LIMIT 1', {} );
$dbh->do(q{alter table tbl_Materials rename column ysntaxexempt1 to taxexempt1}) if exists $$data{ysntaxexempt1};
$dbh->do(q{alter table tbl_Materials rename column ysntaxexempt2 to taxexempt2}) if exists $$data{ysntaxexempt2};
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
	my $ac = sql::start_transaction( $dbh );
$dbh->do(q{CREATE TABLE StockPurposes (
    id  SERIAL NOT NULL,
    name   TEXT NOT NULL,
    PRIMARY KEY (id)
)});
$dbh->do(q{alter table skid_contents add purpose_id integer});
$dbh->do(q{alter table skid_contents add foreign key (purpose_id) references stockpurposes (id)});
$dbh->do(q{insert into stockpurposes (name) values ('House Stock')});
$dbh->do(q{insert into stockpurposes (name) values ('Job Stock')});
$dbh->do(q{insert into stockpurposes (name) values ('Sample')});

$dbh->do(q{alter table paper_inventory rename column updatetime to updated_on});
$dbh->do(q{alter table paper_inventory add id integer});
$dbh->do(q{create sequence paperinventory_id_seq});
$dbh->do(q{alter table paper_inventory alter id set default nextval('paperinventory_id_seq')});
$dbh->do(q{update paper_inventory set id=nextval('paperinventory_id_seq')});
$dbh->do(q{alter table paper_inventory alter id set not null});
$dbh->do(q{alter table paper_inventory add primary key(id)});
	sql::insert( undef, undef, 'database_info', 'version', 1898, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1898;
} # end if
if ( $version < 1899 ) {
	print "Updating to version 1899\n";
	my $ac = sql::start_transaction( $dbh );
$dbh->do(q{alter table skid_contents add primary key (skid_id, paper_id)});
$dbh->do(q{drop index if exists "skid_contents_skid_id_index"});
	sql::insert( undef, undef, 'database_info', 'version', 1899, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1899;
} # end if
if ( $version < 1900 ) {
	print "Updating to version 1900\n";
	my $ac = sql::start_transaction( $dbh );
$dbh->do(q{
CREATE TABLE Quote_Log (
    quote_id    INTeger NOT NULL, FOREIGN KEY(quote_Id) REFERENCES tbl_Quotes (index),
    Company_id  INTeger NOT NULL, FOREIGN KEY(company_id) REFERENCES Company (index),
    User_id     INTeger NOT NULL, FOREIGN KEY(user_id) REFERENCES Users (index),
    dtmwhen     timestamp with time zone NOT NULL default(NOW()),
    Description         TEXT,
    PRIMARY KEY (quote_Id,dtmwhen)
)
});
	sql::insert( undef, undef, 'database_info', 'version', 1900, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1900;
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
	sql::insert( undef, undef, 'database_info', 'version', 1901, 'backup', $backup );
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
	sql::insert( undef, undef, 'database_info', 'version', 1902, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1902;
} # end if
if ( $version < 1903 ) {
	print "Updating to version 1903\n";
	my $ac = sql::start_transaction( $dbh );
$dbh->do(q{alter table papers add minimum_order integer});
$dbh->do(q{alter table papers add inventory_number	text});
	sql::insert( undef, undef, 'database_info', 'version', 1903, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1903;
} # end if
if ( $version < 1904 ) {
	print "Updating to version 1904\n";
	my $ac = sql::start_transaction( $dbh );
$dbh->do(q{alter table papers add full_packages boolean});
	sql::insert( undef, undef, 'database_info', 'version', 1904, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1904;
} # end if
if ( $version < 1905 ) {
	print "Updating to version 1905\n";
	my $ac = sql::start_transaction( $dbh );
$_ = misc::load_file( $log, q{../openprint/sql/Folds.sql});
foreach my $st ( split(';', $_ ) ) {
$dbh->do($st);
}
foreach my $E ( openprint::Equipment::find('Specification'=>{'Folding Capable'=>'When Printing'}) ) {
	foreach my $Spec ( $E->Specifications() ) {
		if ( $Spec->name() =~ /^(\d*)PageSignatureFoldRunSpeed$/ ) {
			my $pages = $1;
			my $Fold = new openprint::Fold();
			$Fold->equipment_id( $E->id() );
			$Fold->name( $pages.'PageSignatureFold' );
			$Fold->type( $pages . 'PageSignatureFold' );
			$Fold->pages( $pages );
			$_ = $Fold->save();
			die $_ if $_;
			my $FS = new openprint::FoldSpecification();
			$FS->fold_id( $Fold->id() );
			$FS->runspeed( $Spec->value() );
			$FS->interpolate( $Spec->interpolate() );
			$_ =  $FS->save();
			die $_ if $_;
			$Spec->delete();

		} elsif ( $Spec->name() =~ /(\d)x(\d)-(\d*)Page-(\w*)FoldDescription/ ) {
			my ( $columns, $rows, $pages, $spine_direction ) = ( $1, $2, $3, $4 );
			my $spread_size = $pages/($columns*$rows);
$spread_size /= 2;
			my $fold = sprintf('%dx%d-%dPage-%sFold', $columns, $rows, $pages, $spine_direction );
			my $Fold = new openprint::Fold();
			$Fold->equipment_id( $E->id() );
			$Fold->name( $Spec->value() );
			$Fold->type( $pages . 'PageSignatureFold' );
			$Fold->pages( $pages );
			$Fold->page_columns( $columns );
			$Fold->page_rows( $rows );
			$Fold->spine_direction( $spine_direction );
			if ( $_ = $E->Specification( $fold.'MinimumWidth' ) ) {
				$Fold->min_width( sprintf( '%.3f', ($_->value()/$columns)/$spread_size ) );
				$_->delete();
			} #end if
			if ( $_ = $E->Specification( $fold.'MaximumWidth' ) ) {
				$Fold->max_width( sprintf('%.3f', ($_->value()/$columns)/$spread_size ) );
				$_->delete();
			} # en dif
			if ( $_ = $E->Specification( $fold.'MinimumHeight' ) ) {
				$Fold->min_height( sprintf('%.3f', ($_->value()/$rows)/$spread_size ) );
				$_->delete();
			} # end if
			if ( $_ = $E->Specification( $fold.'MaximumHeight' ) ) {
				$Fold->max_height( sprintf('%.3f', ($_->value()/$rows)/$spread_size ) );
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
		} elsif ( $Spec->name() =~ /^(\w*)FoldRunSpeed/ ) {
			my $type = $1;
			my $Fold = new openprint::Fold();
			$Fold->equipment_id( $E->id() );
			$Fold->name( $type.'Fold' );
			$Fold->type( $type.'Fold' );
			$_ = $Fold->save();
			die $_ if $_;
			my $FS = new openprint::FoldSpecification();
			$FS->fold_id( $Fold->id() );
			$FS->runspeed( $Spec->value() );
			$FS->interpolate( $Spec->interpolate() );
			$_ =  $FS->save();
			die $_ if $_;
			$Spec->delete();
		} # end if
	} # end foreach
} # end foreach
die if sql::insert( undef, undef, 'database_info', 'version', 1905, 'backup', $backup );
sql::end_transaction( $dbh, $ac );
$version = 1905;
} # end if
if ( $version < 1906 ) {
	print "Updating to version 1906\n";
	my $ac = sql::start_transaction( $dbh );
	my $blah = $dbh->selectrow_hashref( 'SELECT * FROM Quote_Log LIMIT 1', {} );
	if ( ( ! $blah ) or ( $$blah{'dtmwhen'} ) ) {
		$dbh->do(q{alter table quote_log rename column dtmwhen to created_on});
	} # end if
	sql::insert( undef, undef, 'database_info', 'version', 1906, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1906;
} # end if
if ( $version < 1907 ) {
	print "Updating to version 1907\n";
	my $ac = sql::start_transaction( $dbh );
foreach my $E ( openprint::Equipment::find('Specification'=>{'Type'=>'Press'}) ) {
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
	sql::insert( undef, undef, 'database_info', 'version', 1907, 'backup', $backup );
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
	sql::insert( undef, undef, 'database_info', 'version', 1910, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1910;
} # end if
if ( $version < 1911 ) {
	print "Updating to version 1911\n";
	my $ac = sql::start_transaction( $dbh );
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Folds LIMIT 1', {} );
	$dbh->do('alter table folds add min_calliper float') if ! exists $$data{'min_calliper'};
	$dbh->do('alter table folds add max_calliper float') if ! exists $$data{'max_calliper'};
	sql::insert( undef, undef, 'database_info', 'version', 1911, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1911;
} # end if
if ( $version < 1912 ) {
	print "Updating to version 1912\n";
	my $ac = sql::start_transaction( $dbh );
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Folds LIMIT 1', {} );
	$dbh->do('alter table folds add cutting boolean') if ! exists $$data{'cutting'};
	sql::insert( undef, undef, 'database_info', 'version', 1912, 'backup', $backup );
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
	sql::insert( undef, undef, 'database_info', 'version', 1913, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1913;
} # end if
if ( $version < 1914 ) {
	print "Updating to version 1914\n";
	my $ac = sql::start_transaction( $dbh );
	sql::update( undef, undef, 'service_types',['strdetailedurl=?','bind/padding.html'], 'strdetailedurl', 'bind/Padding.html' );
	sql::insert( undef, undef, 'database_info', 'version', 1914, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1914;
} # end if
if ( $version < 1915 ) {
	print "Updating to version 1915\n";
	my $ac = sql::start_transaction( $dbh );
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Users LIMIT 1', {} );
	$dbh->do(q`alter table users add deleted boolean`) if ! exists $$data{'deleted'};
	sql::insert( undef, undef, 'database_info', 'version', 1915, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1915;
} # end if

if ( $version < 1914 ) {
	print "Updating to version 1914\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Labels LIMIT 1', {} );
	if ( ! $data ) {
		my $ac = sql::start_transaction( $dbh );
		$_ = misc::load_file( $log, q{../openprint/sql/Labels.sql});
		foreach my $st ( split(';', $_ ) ) {
			$dbh->do($st);
		}
		sql::end_transaction( $dbh, $ac );
	} # end if
	sql::insert( undef, undef, 'database_info', 'version', 1914, 'backup', $backup );
	$version = 1914;
} # end if
if ( $version < 1915 ) {
	print "Updating to version 1915\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Equipment LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( ! exists $$data{'jdf_name'} ) {
	$dbh->do(q`alter table tbl_equipment add jdf_name text`);
		
	} # end if
	sql::insert( undef, undef, 'database_info', 'version', 1915, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1915;
} # end if
if ( $version < 1916 ) {
	print "Updating to version 1916\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM papers LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( ! exists $$data{'message'} ) {
	$dbh->do(q`alter table papers add message text`);
		
	} # end if
	sql::insert( undef, undef, 'database_info', 'version', 1916, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1916;
} # end if
if ( $version < 1917 ) {
	print "Updating to version 1917\n";
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
	sql::insert( undef, undef, 'database_info', 'version', 1917, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1917;
} # end if
if ( $version < 1918 ) {
	print "Updating to version 1918\n";
	my $ac = sql::start_transaction( $dbh );
	foreach my $E ( openprint::Equipment::find() ) {
		foreach my $Fold ( $E->Folds() ) {
			if ( $Fold->type() =~ /(\d*)PageFold/ ) {
				sql::update( undef, undef, 'Services', ['name=?', "$1PageSignatureFold"], 'name', "$1PageFold" );
			} # end if
		} # end foreach
	} # end foreach
	sql::insert( undef, undef, 'database_info', 'version', 1918, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1918;
} # end if

if ( $version < 1919 ) {
	print "Updating to version 1919\n";
	my $ac = sql::start_transaction( $dbh );
		$_ = misc::load_file( $log, q{../openprint/sql/QuoteLevels.sql});
		foreach my $st ( split(';', $_ ) ) {
			$dbh->do($st);
		}
sql::insert( undef, undef, 'QuoteLevels', 'name', 'Simple' );
sql::insert( undef, undef, 'QuoteLevels', 'name', 'Advanced' );
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
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM service_types LIMIT 1', {} );
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

if ( $version < 1921 ) {
	print "Updating to version 1921\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Equipment LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( ! exists $$data{'jdf_name'} ) {
	$dbh->do(q`alter table tbl_equipment add jdf_name text`);
	} # end if
	sql::insert( undef, undef, 'database_info', 'version', 1921, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1921;
} # end if
if ( $version < 1922 ) {
	print "Updating to version 1922\n";
	my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM tbl_Equipment LIMIT 1', {} );
	my $ac = sql::start_transaction( $dbh );
	if ( ! exists $$data{'jdf_id'} ) {
	$dbh->do(q`alter table tbl_equipment add jdf_id text`);
	} # end if
	sql::insert( undef, undef, 'database_info', 'version', 1922, 'backup', $backup );
	sql::end_transaction( $dbh, $ac );
	$version = 1922;
} # end if

my $new_version = 1923;
if ( $version < $new_version ) {
    print "Updating to version $new_version\n";
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
    sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
    $version = $new_version;
} # end if
my $new_version = 1924;
if ( $version < $new_version ) {
    print "Updating to version $new_version\n";
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
    sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
    $version = $new_version;
} # end if

my $new_version = 1925;
if ( $version < $new_version ) {
    print "Updating to version $new_version\n";
    my $ac = sql::start_transaction( $dbh );
    my $data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM User_Service_Defaults LIMIT 1', {} );
    if ( ! $data ) {
        $_ = misc::load_file( $log, q{../openprint/sql/User_Service_Defaults.sql});
        foreach my $st ( split(';', $_ ) ) {
            $dbh->do($st);
        }
    } # end if
    sql::insert( undef, undef, 'database_info', 'version', $new_version, 'backup', $backup );
    sql::end_transaction( $dbh, $ac );
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

$dbh->disconnect();
1;
__END__
