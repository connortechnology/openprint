#!/usr/bin/perl
use lib '/var/www/testing/perl';
use Date::Calc;
use strict;
require sql;
require logger;
require openprint::Object;
require openprint::Project;
require openprint::service;

use openprint ();
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

$log = new logger( 'warn' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'database'} = 'topknotch' if ! $sql_server{'database'};
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'login'} = $sql_server{'database'} if ! $sql_server{'login'};
$sql_server{'password'} = $ARGV[2];
$sql_server{'password'} = $sql_server{'login'} if ! $sql_server{'password'};

$openprint::Object::no_cache = 1;
my $projects_count = 100;
my $project_id = 0;
my $company_id = 6;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;

my $ServiceType = openprint::ServiceType->find_one('name'=>'Signature');
if ( ! $ServiceType ) {
	$ServiceType = openprint::ServiceType->find_one('name'=>'AdditionalSignature');
	$ServiceType->save({'name'=>'Signature','type'=>'Printing','url'=>'prin/Signature.html'});
}
if ( ! $ServiceType ) {
	$ServiceType = new openprint::ServiceType();
	$ServiceType->save({'name'=>'Signature','description'=>'Signature','url'=>'prin/Signature.html','view_visible'=>1,'category'=>'Printing','type'=>'Printing'});
}

foreach my $Project ( openprint::Project->find( 'order'=>'id desc',
	( $project_id ? ( 'id'=>$project_id) : () ),
	( $company_id ? ('company_id'=>$company_id) : () ),
	'limit'=>$projects_count ) ) {
	my $services = $Project->services();

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] ) if $$services{''};

	foreach my $sig_id ( $Project->signatures() ? $Project->signatures() : $$services{''}[0] ) {
		next if ! $sig_id;
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		if ( $$sig_specs{'ServiceType'} eq 'AdditionalSignature' ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ServiceType', 'Signature' );
		} # end if
	} # end foreach sig_id
	openprint::service::init_cache();
} # end foreach Project
openprint::Object::init_cache();
if ( 1 ) {
	my $Type = openprint::ProjectType->find_one('name'=>'MultiPagePublication');
	if ( $Type ) {
		$Type->save({'name'=>'MultiPage'});
		sql::update( undef, undef, 'tbl_service_specifications',[ 'strname=? AND strvalue=?', 'ProjectType', 'MultiPagePublication' ], 'strvalue', 'MultiPage' );
	} else {
		$Type = openprint::ProjectType->find_one('name'=>'MultiPage');
	} # end if

	if ( $Type ) {
		foreach my $Project ( openprint::Project->find( 'order'=>'id desc','limit'=>$projects_count  ) ) {
			# Skip multipage projects
			next if sets::isin( $Project->Type()->name(), [ 'MultiPage', 'Newsletters','Magazines','Calendars' ] );
			my $services = $Project->services();
			next if $$services{'Signature'};
			next if ! $$services{''};
			next if ! $$services{''}[0];
			my $print_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
			my $new_signature = $Project->copy_signature( $print_specs, {}, openprint::service::status( $Project->id(), $$services{''}[0] ) );
			foreach my $qty_index ( $Project->quantity_indexes() ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $$services{''}[0], 'txtPrice'.$qty_index, 0 );
			} # end foreach
		} # end foreach Project
	} # end if Type
	$dbh->do(q`UPDATE project_types set url=NULL where url='prin/prin_broc.html'`);
}
$dbh->do(q`DELETE FROM tbl_projecttype_defaults where strfieldname='rdbAqueousSideOne'`);
$dbh->do(q`DELETE FROM tbl_projecttype_defaults where strfieldname='rdbAqueousSideTwo'`);
$dbh->do(q`DELETE FROM tbl_projecttype_defaults where strfieldname='rdbGripHeight'`);
$dbh->do(q`DELETE FROM tbl_projecttype_defaults where strfieldname='rdbGripWidth'`);
$dbh->do(q`DELETE FROM tbl_projecttype_defaults where strfieldname='rdbWaxFree'`);
require openprint::ProjectType_Default;
require openprint::ServiceType_Default;
my $ServiceType = openprint::ServiceType->find_one('name'=>'Signature');
if ( ! $ServiceType ) {
	die 'Should have Signature by now';
}
foreach my $Default ( openprint::ProjectType_Default->find('projecttype'=>'Letterhead') ) {
	my $SD = new openprint::ServiceType_Default();
	$SD->save({	
			'name'			=>	$Default->name(),
			'value'			=>	$Default->value(),
			'projecttype_id'=>	$Default->projecttype_id(),
			'servicetype_id'	=>	$ServiceType->id(),
			} );
	$Default->destroy();
} # end foreach
foreach my $Default ( openprint::ProjectType_Default->find('projecttype'=>undef) ) {
	my $SD = new openprint::ServiceType_Default();
	$SD->save({	
			'name'			=>	$Default->name(),
			'value'			=>	$Default->value(),
			'projecttype_id'=>	$Default->projecttype_id(),
			'servicetype_id'	=>	$ServiceType->id(),
			} );
	$Default->destroy();
} # end foreach

$dbh->disconnect();
	
1;
__END__
