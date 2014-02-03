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
$sql_server{'database'} = 'point-one' if ! $sql_server{'database'};
$sql_server{'driver'}   = 'Pg';
$sql_server{'login'}    = $ARGV[1];
$sql_server{'login'} = $sql_server{'database'} if ! $sql_server{'login'};
$sql_server{'password'} = $ARGV[2];
$sql_server{'password'} = $sql_server{'login'} if ! $sql_server{'password'};

$openprint::Object::no_cache = 1;
my $projects_count = 10000;
my $project_id = $ARGV[3];
#
#my $project_id = 407192;
my $company_id = 0;

$dbh = sql::open_sql( $log, %sql_server );
my @projects;

if ( 1 ) {
$log->warn("Updating $projects_count projects for $company_id or just $project_id");
foreach my $Project ( openprint::Project->find( order=>'id desc',
	( $project_id ? ( id=>$project_id) : 
	( $company_id ? (company_id=>$company_id) : () ),
	),
	offset=>$projects_count ) ) {
#$log->warn("Updating rpoject $$Project{id}");
	my $services = $Project->services();

	if ( $$services{''} ) {
		my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
#if ( ! $Project->signatures() ) {
#$log->warn("Not signatures $$Project{id}");
#} # end if

		foreach my $sig_id ( $Project->signatures() ? $Project->signatures() : $$services{''}[0] ) {
			next if ! $sig_id;
			my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
			if ( $$sig_specs{'ServiceType'} eq 'AdditionalSignature' ) {
				$log->debug("Changing ServiceType to Signatuer");
# Don't need to delete, becaeuse insert does a delete by default
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ServiceType', 'Signature' );
			} # end if

			if ( $$sig_specs{'SignatureIndex'} eq '' ) {
				$log->warn("Updating sig $sig_id of project $$Project{'id'} adding SignatureIndex");
				$_ = q{SELECT MAX(strValue::integer) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
				my ( $sig_index ) = sql::execute( undef, undef, $_, $Project->id() );
				$sig_index += 1;
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'SignatureIndex', $sig_index );
			} # end if
			foreach my $bleed ( 'Left','Right','Top','Bottom' ) {
				if ( $$sig_specs{'chkBleed'.$bleed} ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Bleed'.$bleed, $$sig_specs{'chkBleed'.$bleed} );
					openprint::service::delete_service_spec( $Project->id(), $sig_id, 'chkBleed'.$bleed );
#openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkBleed'.$bleed, '' );
				} # end if
			} # end foreach
#if ( ! exists $$sig_specs{'Group'} ) {
			if ( $$sig_specs{'txtSignatureType'} ) {
				if ( ! $$sig_specs{txtFinalWidth} ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'txtFinalWidth', $$sig_specs{txtWidth} );
				} # end if
				if ( ! $$sig_specs{txtFinalHeight} ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'txtFinalHeight', $$sig_specs{txtHeight} );
				} # end if

				if ( $$sig_specs{'txtSignatureType'} eq 'Cover Spreads' or $$sig_specs{'txtSignatureType'} eq 'Cover Pages' ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'txtSignatureType', 'Cover Pages' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Group', '1' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'GroupPageQuantity', '4' );

				} elsif ( $$sig_specs{'txtSignatureType'} eq 'Interior Spreads' or $$sig_specs{'txtSignatureType'} eq 'Interior Pages' ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'txtSignatureType', 'Interior Pages' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Group', '2' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'GroupPageQuantity', $$printing_specs{'txtTotalPageQuantity'} - ( $$printing_specs{'rdbCover'} eq 'Self' ? 0 : 4 ) );
					foreach my $qty_index ( $Project->quantity_indexes() ) {
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'MatchGrain'.$qty_index, 'Y' );
					} # end foreach
				} else {
		# Gate Fold?
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'Group', '3' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'GroupPageQuantity', '4' );
				} # end if
			} # end if

			foreach my $qty_index ( $Project->quantity_indexes() ) {
				if ( $$sig_specs{'chkOverridePrintingType'.$qty_index} eq 'Y' ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'OverridePrintingType'.$qty_index, 'Y' );
					openprint::service::delete_service_spec( $Project->id(), $sig_id,'chkOverridePrintingType'.$qty_index);
				} # end if
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
					if ( $$sig_specs{"chkSpecial${side}Colour$colour_index"} eq 'Y' ) {
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkColourCoating'.$index.$side, 'Y' );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$index.$side, 'PMS' );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingColour'.$index.$side,  $$sig_specs{"txtSpecial${side}Colour$colour_index"} );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingCoverage'.$index.$side,  $$sig_specs{"txtSpecial${side}ColourInkPercent$colour_index"} );
						$index += 1;
					} # end if
				} # end foreach index
				if ( sets::isin( $$sig_specs{'rdbAqueous'.$side}, ['Gloss','Matte','Satin','SoftTouch'] ) ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkColourCoating'.$index.$side, 'Y' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$index.$side, 'Aqueous '.$$sig_specs{'rdbAqueous'.$side} );
					$index += 1;
				} # end if
				if ( $$sig_specs{'chkVarnishOverallGloss'.$side} ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkColourCoating'.$index.$side, 'Y' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$index.$side, 'Varnish Gloss Overall' );
					$index += 1;
				} # end if	
				if ( $$sig_specs{'chkVarnishSpotGloss'.$side} ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'chkColourCoating'.$index.$side, 'Y' );
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $sig_id, 'ColourCoatingType'.$index.$side, 'Varnish Gloss Spot' );
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

			if ( $$services{'Scoring'} ) {
				foreach my $scoring_service_id ( @{$$services{'Scoring'}} ) {
					my $scoring_specs = openprint::service::get_specs_ref( $Project, $scoring_service_id );
					foreach my $sig_id ( $Project->signatures() ? $Project->signatures() : $$services{''}[0] ) {
						my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
						foreach my $qty_index ( $Project->quantity_indexes() ) {
							next if ! $$scoring_specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"};
							next if ! ( $$scoring_specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} =~ /\D/ );
							my $Equipment = openprint::Equipment->find_one( 'strid'=>$$scoring_specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"}, deleted=>[0,1,undef] );
							if ( ! $Equipment ) {
								$log->error( 'No equipment found for ' . $$scoring_specs{"ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index"} );
								next;
							} 
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $scoring_service_id, "ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index", $Equipment->id() );
						} # end foreach
					} # end foreach sig

				} # end foreach service_id in Scoring
			} # end if Scoring

		} # end foreach sig_id
	} # end if
	foreach my $service ( 'BulkSkids', 'PlainCartons' ) {
		if ( $$services{$service} ) {
			foreach my $ss_id ( @{$$services{$service}} ) {
				my $specs = openprint::service::get_specs_ref( $Project, $ss_id );
				foreach my $qty_index ( $Project->quantity_indexes() ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, 'ddmPackageType'.$qty_index, $$specs{'ddmPackageType'} );
					if ( $$specs{'ddmPackageType'.$qty_index} =~ /\D/ ) {
						if ( my $Material = openprint::Material->find_one( 'name'=>$$specs{'ddmPackageType'.$qty_index} ) ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, 'ddmPackageType'.$qty_index, $Material->id() );
						} # end if
					} # end if
					if ( $$specs{'chkOverrideItemsPerPackage'} ) {
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, 'OverrideItemsPerPackage'.$qty_index, $$specs{'chkOverrideItemsPerPackage'} );
					} # end if
					if ( $$specs{'txtItemsPerPackage'} ) {
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $ss_id, 'txtItemsPerPackage'.$qty_index, $$specs{'txtItemsPerPackage'} );
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
	openprint::service::init_cache();

} # end foreach Project
openprint::Object::init_cache();
}
if ( 1 ) {
	my $Type = openprint::ProjectType->find_one('name'=>'MultiPagePublication');
	if ( $Type ) {
		$Type->save({'name'=>'MultiPage'});
		sql::update( undef, undef, 'tbl_service_specifications',[ 'strname=? AND strvalue=?', 'ProjectType', 'MultiPagePublication' ], 'strvalue', 'MultiPage' );
	} else {
		$Type = openprint::ProjectType->find_one('name'=>'MultiPage');
	} # end if

	if ( $Type ) {
		foreach my $Project ( openprint::Project->find( 'order'=>'id desc',
					( $project_id ? ( 'id'=>$project_id) : () ),
					( $company_id ? ( 'company_id'=>$company_id ) : () ),
					offset=>$projects_count  ) ) {
# Skip multipage projects
			next if sets::isin( $Project->Type()->name(), [ 'MultiPage', 'Magazines','Calendars' ] );
			my $services = $Project->services();
			next if ! $$services{''};
			next if ! $$services{''}[0];
			next if $$services{'Signature'};
			my $print_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
			my $new_signature = $Project->copy_signature( $print_specs, {}, openprint::service::status( $Project->id(), $$services{''}[0] ) );
			foreach my $qty_index ( 1 .. 3 ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $$services{''}[0], 'txtPrice'.$qty_index, 0 );
			} # end foreach
			if ( $$services{'Folding'} ) {
				my %fold_types = (
						'2PanelFold', '2 Panel Fold',
						'3PanelFold', '3 Panel Fold',
						'3PanelZFold', '3 Panel Z Fold',
						'4PanelFold', '4 Panel Fold',
						'4PanelZFold', '4 Panel Z Fold',
						'5PanelFold', '5 Panel Fold',
						'5PanelZFold', '5 Panel Z Fold',
						'6PanelFold', '6 Panel Fold',
						'6PanelZFold', '6 Panel Z Fold',
						'SingleGateFold', 'Single Gate Fold',
						'DoubleGateFold', 'Double Gate Fold',
						'4PageSignatureFold', '4PageSignatureFold',
						'6PageSignatureFold', '6PageSignatureFold',
						'8PageSignatureFold', '8PageSignatureFold',
						'12PageSignatureFold', '12PageSignatureFold',
						'16PageSignatureFold', '16PageSignatureFold',
						'18PageSignatureFold', '18PageSignatureFold',
						'20PageSignatureFold', '20PageSignatureFold',
						'24PageSignatureFold', '24PageSignatureFold',
						'28PageSignatureFold', '28PageSignatureFold',
						'32PageSignatureFold', '32PageSignatureFold',
						'36PageSignatureFold', '36PageSignatureFold',
						'40PageSignatureFold', '40PageSignatureFold',
						'44PageSignatureFold', '44PageSignatureFold',
						'48PageSignatureFold', '48PageSignatureFold',
						'PerpendicularSoftFold', 'PerpendicularSoftFold',
						'ParallelSoftFold', 'ParallelSoftFold',
						'2Panel1Pocket', 'Single Pocket Presentation Folder',
						'2Panel2Pocket', 'Double Pocket Presentation Folder',
						'2Panel2PocketGusset', 'Double Pocket Presentation Folder with Gussets',
						'3Panel2Pocket', '3 Panel Double Pocket Presentation Folder',
						'3Panel2PocketGusset', '3 Panel Double Pocket Presentation Folder with Gussets',
						'MapFold','Map Fold',
						);
				foreach my $service ( @{$$services{'Folding'}} ) {
					my $specs = openprint::service::get_specs_ref( $Project, $service );
					foreach my $qty_index ( $Project->quantity_indexes() ) {
						if ( $$specs{"ddmEquipment-0-$qty_index"} and ! $$specs{"ddmEquipment-1-$qty_index"} ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, "ddmEquipment-1-$qty_index", $$specs{"ddmEquipment-0-$qty_index"} );
							openprint::service::delete_service_spec( $Project->id(), $service, "ddmEquipment-0-$qty_index" );
						} # end if
						foreach my $sig ( $Project->signatures() ) {
							my $sig_specs = openprint::service::get_specs_ref( $Project, $sig );

							if ( $$specs{"chkOverrideFoldType-$$sig_specs{'SignatureIndex'}-$qty_index"} ) {
								openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, "chkOverrideFold-$$sig_specs{'SignatureIndex'}-$qty_index", $$specs{"chkOverrideFoldType-$$sig_specs{'SignatureIndex'}-$qty_index"} );
								openprint::service::delete_service_spec( $Project->id(), $service, "chkOverrideFoldType-$$sig_specs{'SignatureIndex'}-$qty_index" );
							} # end if
							foreach my $fold_type ( keys %fold_types ) {
								if ( $$specs{"$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} ) {
									openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, "FoldQty-$$sig_specs{'SignatureIndex'}-$qty_index-1", $$specs{"$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} );
									my $new_fold_type = $fold_type;
									$new_fold_type =~ s/Signature//g;
									openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, "FoldType-$$sig_specs{'SignatureIndex'}-$qty_index-1", $new_fold_type );
									openprint::service::delete_service_spec( $Project->id(), $service, "$fold_type-Qty-$$sig_specs{'SignatureIndex'}-$qty_index" );
								} # end if
							} # end foreach
						} # end foreach
					}
				} # end foraech service
			} # end if
			if ( $$services{'Proofs'} ) {
				foreach my $service ( @{$$services{'Proofs'}} ) {
					my $specs = openprint::service::get_specs_ref( $Project, $service );
					foreach my $key ( keys %{$specs} ) {
						if ( $key =~ /^txtProofIndex-0-(\d*)-(\d*)$/ ) {
							my ( $proof_index, $qty_index ) = ( $1, $2 );

							foreach my $spec ( 
									'txtProofWidth',
									'txtProofHeight',
									'txtProofQuantity',
									'ddmProofType',
									'txtProofUnitPrice',
									'txtProofIndex',
									'chkOverride',) {

								openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, "$spec-1-$proof_index-$qty_index", $$specs{"$spec-0-$proof_index-$qty_index"} );
								openprint::service::delete_service_spec( $Project->id(), $service, "$spec-0-$proof_index-$qty_index" );
							} # end foreach spec
						} # end if
					} # end foreach key
				} # end foraech service
			} # end if Proofs
			if ( $$services{'Cutting'} ) {
				foreach my $service ( @{$$services{'Cutting'}} ) {
					my $specs = openprint::service::get_specs_ref( $Project, $service );
					foreach my $spec ( "txtStockCalliper-", "chkOverrideCalliper-", "txtAdditionalCuts" ) {
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, $spec.'1', $$specs{$spec.'0'} );
						openprint::service::delete_service_spec( $Project->id(), $service, $spec.'0' );
					} # end foreach
					foreach my $spec ( 
							"txtCalculatedCuts",
							"ddmEquipment",
							"ddmStockCutEquipment",
							"chkOverrideStockCutEquipment",
							"chkOverrideCalculatedCuts",
							"OverrideVerticalCuts",
							"txtVerticalCuts",
							"OverrideHorizontalCuts",
							"txtHorizontalCuts",
							"OverrideDVerticalCuts",
							"txtDVerticalCuts",
							"OverrideDHorizontalCuts",
							"txtDHorizontalCuts",
							) {
						foreach my $qty_index ( $Project->quantity_indexes() ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service, "$spec-1-$qty_index", $$specs{"$spec-0-$qty_index"} );
							openprint::service::delete_service_spec( $Project->id(), $service, "$spec-0-$qty_index" );
						} # end foreach qty
					} # end foreach spec
				} # end foraech service
			} # end if Cutting
			if ( $$services{'Perforating'} ) {
				foreach my $service_id ( @{$$services{'Perforating'}} ) {
					my $specs = openprint::service::get_specs_ref( $Project, $service_id );
					foreach my $spec ( 'txtHorizontalQty', 'txtVerticalQty' ) {
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $spec.'-1', $$specs{$spec.'-0'} );
						openprint::service::delete_service_spec( $Project->id(), $service_id, $spec.'0' );
					} # end foreach specs
					foreach my $spec ( 'txtLayoutWidth','txtLayoutHeight','txtImposition' ) {
						foreach my $qty_index ( $Project->quantity_indexes() ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, "$spec-1-$qty_index", $$specs{"$spec-0-$qty_index"} );
							openprint::service::delete_service_spec( $Project->id(), $service_id, "$spec-0-$qty_index" );
						} # end foreach qty_index
					} # end foreach spec

				} # end foreach service_id in Perforating
			} # end if Perforating
			if ( $$services{'Scoring'} ) {
				foreach my $service_id ( @{$$services{'Scoring'}} ) {
					my $specs = openprint::service::get_specs_ref( $Project, $service_id );
					foreach my $spec ( 'txtHorizontalQty', 'txtVerticalQty' ) {
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, $spec.'-1', $$specs{$spec.'-0'} );
						openprint::service::delete_service_spec( $Project->id(), $service_id, $spec.'0' );
					} # end foreach specs
					foreach my $spec ( 'txtLayoutWidth','txtLayoutHeight','txtImposition','chkOverrideImposition', 'ddmEquipment','chkOverrideEquipment' ) {
						foreach my $qty_index ( $Project->quantity_indexes() ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $service_id, "$spec-1-$qty_index", $$specs{"$spec-0-$qty_index"} );
							openprint::service::delete_service_spec( $Project->id(), $service_id, "$spec-0-$qty_index" );
						} # end foreach qty_index
					} # end foreach spec

				} # end foreach service_id in Scoring
			} # end if Scoring
		} # end foreach Project
	} # end if Type
	$dbh->do(q`UPDATE project_types set url=NULL where url='prin/prin_broc.html'`);
}

$dbh->disconnect();

1;
__END__
