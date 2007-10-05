#!/usr/bin/perl
use lib '/etc/apache2/lib/perl';
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

$log = new logger( 'debug' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'point-one';
$sql_server{'password'} = 'point-1';

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );
foreach my $Project ( openprint::Project::find('id_start'=>200000,'order'=>'index desc') ) {
	my $project_index = $Project->id();
	my %services = $Project->get_services();
$log->warn("Looking at Project $project_index");
	next if ! $services{'Proofs'};
	my $service_index = $services{'Proofs'}[0];
	my $ac = sql::start_transaction( $dbh );
	my %specs = openprint::service::get_specifications_pairs( $log, $dbh, $Project->id(), $services{'Proofs'}[0] );

	foreach my $key ( keys %specs ) {
		if ( $key =~ /^ddmProofType-(\d*)-(\d*)$/ ) {
			my ( $signature_index, $proof_index ) = ( $1, $2 );
			foreach my $qty_index ( 1 .. 3 ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $services{'Proofs'}[0], "chkOverride-$signature_index-$proof_index-$qty_index", $specs{"chkOverride-$signature_index-$proof_index"} eq 'checked' ? 'Y' : '' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $services{'Proofs'}[0], "txtProofWidth-$signature_index-$proof_index-$qty_index", $specs{"txtProofWidth-$signature_index-$proof_index"} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $services{'Proofs'}[0], "txtProofHeight-$signature_index-$proof_index-$qty_index", $specs{"txtProofHeight-$signature_index-$proof_index"} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $services{'Proofs'}[0], "txtProofQuantity-$signature_index-$proof_index-$qty_index", $specs{"txtProofQuantity-$signature_index-$proof_index"} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $services{'Proofs'}[0], "ddmProofType-$signature_index-$proof_index-$qty_index", $specs{"ddmProofType-$signature_index-$proof_index"} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $services{'Proofs'}[0], "txtProofIndex-$signature_index-$proof_index-$qty_index", $proof_index );
				sql::execute( undef, undef, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?}, $project_index, $service_index, "chkOverride-$signature_index-$proof_index" );
				sql::execute( undef, undef, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?}, $project_index, $service_index, "txtProofQuantity-$signature_index-$proof_index" );
				sql::execute( undef, undef, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?}, $project_index, $service_index, "txtProofWidth-$signature_index-$proof_index" );
				sql::execute( undef, undef, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?}, $project_index, $service_index, "txtProofHeight-$signature_index-$proof_index" );
				sql::execute( undef, undef, q{DELETE FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex=? AND strName=?}, $project_index, $service_index, "ddmProofType-$signature_index-$proof_index" );



			} # end foreach
		} # end if
	} # end foreach
	sql::end_transaction( $dbh, $ac );
	openprint::service::init_cache();
} # end foreach
