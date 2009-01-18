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
$sql_server{'database'} = 'point-one' if ! $sql_server{'database'};
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = 'point-one';
$sql_server{'password'} = 'point-one';

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;

foreach my $Project ( openprint::Project::find('id_start'=>304000,'company_id'=>6) ) {
	foreach my $sig_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		foreach my $side ( 'SideOne','SideTwo' ) {
			my $index;
			foreach $index ( 1 .. 8 ) {
				last if ! $$sig_specs{'ColourCoatingColour'.$side.$index};
			} # end foreach
			$index += 1;
			$index = 1 if $index >= 8;
			foreach my $colour_index ( 1 .. 8 ) {
				if ( $$sig_specs{"chkSpecialSideOneColour$colour_index"} eq 'Y' ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoating'.$side.$index, 'Y' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$side.$index, 'PMS' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingColour'.$side.$index,  $$sig_specs{"txtSpecialSideOneColour$colour_index"} );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingCoverage'.$side.$index,  $$sig_specs{"txtSpecialSideOneColourInkPercent$colour_index"} );
					$index += 1;
				} # end if
			} # end foreach index
			if ( sets::isin( $$sig_specs{'rdbAqueous'.$side}, ['Gloss','Matte'] ) ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoating'.$side.$index, 'Y' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$side.$index, 'Aqueous '.$$sig_specs{'rdbAqueous'.$side}.' Overall' );
				$index += 1;
			} # end if
			if ( $$sig_specs{'chkVarnishOverallGloss'.$side} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoating'.$side.$index, 'Y' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$side.$index, 'Varnish Gloss Overall' );
				$index += 1;
			} # end if	
			if ( $$sig_specs{'chkVarnishSpotMatte'.$side} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoating'.$side.$index, 'Y' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$side.$index, 'Varnish Matte Spot' );
				$index += 1;
			} # end if	
			if ( $$sig_specs{'chkVarnishOverallMatte'.$side} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoating'.$side.$index, 'Y' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$side.$index, 'Varnish Matte Overall' );
				$index += 1;
			} # end if	
			if ( $$sig_specs{'chkVarnishSpotMatte'.$side} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoating'.$side.$index, 'Y' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$side.$index, 'Varnish Matte Spot' );
				$index += 1;
			} # end if	
		} # end foreach side
	} # end foreach sig_id
	my $services = $Project->services();
	foreach my $service ( 'BulkSkids', 'PlainCartons' ) {
		if ( $$services{$service} ) {
			foreach ( @{$$services{$service}} ) {
				my $specs = openprint::service::get_specs_ref( $Project, $_ );
				foreach my $qty_index ( $Project->quantity_indexes() ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $_, 'ddmPackageType'.$qty_index, $$specs{'ddmPackageTYpe'} );
				} # end foreach
			} # end foreach
		} # end if
	} # end foreach service
} # end foreach
