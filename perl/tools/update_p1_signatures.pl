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

$log = new logger( 'debug' );
my %sql_server;
$sql_server{'database'} = $ARGV[0];
$sql_server{'database'} = 'point-one' if ! $sql_server{'database'};
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'login'} = $sql_server{'database'} if ! $sql_server{'login'};
$sql_server{'password'} = $ARGV[2];
$sql_server{'password'} = $sql_server{'database'} if ! $sql_server{'password'};

$openprint::Object::no_cache = 1;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;

foreach my $bleed ( 'Top','Bottom','Left','Right' ) {
sql::update( undef, undef, 'tbl_ProjectType_Defaults', ['strfieldname=?', 'chkBleed'.$bleed], 'strfieldname', 'Bleed'.$bleed );
sql::update( undef, undef, 'tbl_service_Defaults', ['strfieldname=?', 'chkBleed'.$bleed], 'strfieldname', 'Bleed'.$bleed );
} # end foreach bleed

foreach my $Project ( openprint::Project::find( 'order'=>'id desc','limit'=>1000 ) ) {
	my $services = $Project->services();

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] ) if $$services{''};

	foreach my $sig_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		foreach my $bleed ( 'Left','Right','Top','Bottom' ) {
			if ( $$sig_specs{'chkBleed'.$bleed} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Bleed'.$bleed, $$sig_specs{'chkBleed'.$bleed} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkBleed'.$bleed, '' );
			} # end if
		} # end foreach
		#if ( ! exists $$sig_specs{'Group'} ) {
		if ( $$sig_specs{'txtSignatureType'} ) {
			if ( $$sig_specs{'txtSignatureType'} eq 'Cover Spreads' or $$sig_specs{'txtSignatureType'} eq 'Cover Pages' ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'txtSignatureType', 'Cover Pages' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Group', '1' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'GroupPageQuantity', '4' );
		
			} elsif ( $$sig_specs{'txtSignatureType'} eq 'Interior Spreads' or $$sig_specs{'txtSignatureType'} eq 'Interior Pages' ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'txtSignatureType', 'Interior Pages' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Group', '2' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'GroupPageQuantity', $$printing_specs{'txtTotalPageQuantity'} - ( $$printing_specs{'rdbCover'} eq 'Self' ? 0 : 4 ) );
			} else {
				# Gate Fold?
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Group', '3' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'GroupPageQuantity', '4' );
			} # end if
		} # end if

		foreach my $qty_index ( $Project->quantity_indexes() ) {
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
		foreach my $side ( 'SideOne','SideTwo' ) {
			my $index;
			foreach $index ( 1 .. 8 ) {
				last if ! $$sig_specs{'ColourCoatingColour'.$index.$side};
			} # end foreach
			$index += 1;
			$index = 1 if $index >= 8;
			foreach my $colour_index ( 1 .. 8 ) {
				if ( $$sig_specs{"chkSpecialSideOneColour$colour_index"} eq 'Y' ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkColourCoating'.$index.$side, 'Y' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$index.$side, 'PMS' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingColour'.$index.$side,  $$sig_specs{"txtSpecialSideOneColour$colour_index"} );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingCoverage'.$index.$side,  $$sig_specs{"txtSpecialSideOneColourInkPercent$colour_index"} );
					$index += 1;
				} # end if
			} # end foreach index
			if ( sets::isin( $$sig_specs{'rdbAqueous'.$side}, ['Gloss','Matte'] ) ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkColourCoating'.$index.$side, 'Y' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$index.$side, 'Aqueous '.$$sig_specs{'rdbAqueous'.$side}.' Overall' );
				$index += 1;
			} # end if
			if ( $$sig_specs{'chkVarnishOverallGloss'.$side} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkColourCoating'.$index.$side, 'Y' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$index.$side, 'Varnish Gloss Overall' );
				$index += 1;
			} # end if	
			if ( $$sig_specs{'chkVarnishSpotMatte'.$side} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkColourCoating'.$index.$side, 'Y' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$index.$side, 'Varnish Matte Spot' );
				$index += 1;
			} # end if	
			if ( $$sig_specs{'chkVarnishOverallMatte'.$side} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkColourCoating'.$index.$side, 'Y' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$index.$side, 'Varnish Matte Overall' );
				$index += 1;
			} # end if	
			if ( $$sig_specs{'chkVarnishSpotMatte'.$side} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkColourCoating'.$index.$side, 'Y' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$index.$side, 'Varnish Matte Spot' );
				$index += 1;
			} # end if	
		} # end foreach side
	} # end foreach sig_id
	foreach my $service ( 'BulkSkids', 'PlainCartons' ) {
		if ( $$services{$service} ) {
			foreach my $ss_id ( @{$$services{$service}} ) {
				my $specs = openprint::service::get_specs_ref( $Project, $ss_id );
				foreach my $qty_index ( $Project->quantity_indexes() ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, 'ddmPackageType'.$qty_index, $$specs{'ddmPackageType'} );
					if ( $$specs{'ddmPackageType'.$qty_index} =~ /\D/ ) {
						if ( my $Material = openprint::Material::find_one( 'name'=>$$specs{'ddmPackageType'.$qty_index} ) ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, 'ddmPackageType'.$qty_index, $Material->id() );
						} # end if
					} # end if
				} # end foreach
			} # end foreach
		} # end if
	} # end foreach service
	foreach my $service ( 'Padding' ) {
		if ( $$services{$service} ) {
			foreach my $ss_id ( @{$$services{$service}} ) {
				my $specs = openprint::service::get_specs_ref( $Project, $ss_id );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, 'rdbCardboardBacking', $$specs{'rdbCardboardBacking'} eq 'Y' ? 'Cardboard' : 'None' );
			} # end foreach ssid
		} # end if
	} # end foreach
	my $summary = $Project->summary();

	sql::update( undef, undef, 'Projects', ['id=?', $Project->id()], 'summary', $summary );

} # end foreach Project
1;
__END__
