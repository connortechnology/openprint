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
$sql_server{'password'} = 'point-one';

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;
push @projects, openprint::Project::find( 'id_start'=>244000, 'company_id'=>6, 'order'=>'index desc');

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
