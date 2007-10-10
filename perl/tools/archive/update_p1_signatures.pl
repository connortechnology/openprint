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
my @projects;
#push @projects, map { new openprint::Project( $_ ); } sql::execute( undef, undef, q{SELECT DISTINCT projectindex from Schedule} );
#push @projects, openprint::Project::find( 'id'=>222386, 'company_id'=>6, 'id_start'=>200000, 'order'=>'index desc');
push @projects, openprint::Project::find( 'id_end'=>'150000', 'order'=>'index desc');
#@projects = sets::union( @projects );

foreach my $Project ( @projects ) {
	my $project_index = $Project->id();
	my $ref = $Project->reference();
	$ref =~ s/<br>/\r\n/mg;
	if ( $Project->reference() ne $ref ) {
		$Project->reference( $ref );
		$Project->save();
	} # end if
	if ( ! $Project->currency_id() ) {
		$Project->currency_id( $Project->Company()->currency_id() );
		$Project->currency_id( 1 ) if ! $Project->currency_id();
		$Project->save();
	} # end if
	my %services = $Project->get_services();
#$log->warn("Looking at Project $project_index");
	my $ac = sql::start_transaction( $dbh );
	if ( $services{'AdditionalSignature'} ) {
		my $p_specs = openprint::service::get_specs_ref( $Project->id(), $services{''}[0] );
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $services{''}[0], 'txtSpreadSize', 4 ) if ! $$p_specs{'txtSpreadSize'};
		
		foreach my $s_id ( @{$services{'AdditionalSignature'}} ) {
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );

			if ( exists $$specs{'BleedSize1'} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ddmBleedSize1', $$specs{'BleedSize1'});
			} 
			if ( exists $$specs{'BleedSize2'} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ddmBleedSize2', $$specs{'BleedSize2'});
			} 
			if ( exists $$specs{'BleedSize3'} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ddmBleedSize3', $$specs{'BleedSize3'});
			} 
			if ( exists $$specs{'BleedSize'} ) {
				foreach my $qty_index ( 1 .. 3 ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ddmBleedSize'.$qty_index, $$specs{'BleedSize'} ) if $$specs{'txtQuantity'.$qty_index};
				if ( $$specs{'BleedSize'} eq '0.0000' ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'chkOverrideBleedSize'.$qty_index, 'Y' ) if $$specs{'txtQuantity'.$qty_index};
				} # end if
				} # end 
			} # end 
					
			foreach my $key ( 'ddmRunStyle','ddmPress','ddmBleedSize','txtSignatureSpreadQuantity','txtUnspecifiedSpreadQuantity','ddmStockSheetSize','rdbPlateType','txtPlateQuantity','txtImposition','hdnImpositionRows','hdnImpositionColumns','chkOverrideRunStyle','chkOverridePress','hdnImageOrientation','txtMWeight','chkOverrideSignatureSpreadQuantity','rdbGrainDirection','hdnSuppliedStockWidth','hdnSuppliedStockHeight','txtPlateChangeQuantity') {
				next if ! exists $$specs{$key};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, $key.'1', $$specs{$key}, ! exists $$specs{$key.1} ) if $$specs{'txtQuantity1'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, $key.'2', $$specs{$key}, ! exists $$specs{$key.2} ) if $$specs{'txtQuantity2'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, $key.'3', $$specs{$key}, ! exists $$specs{$key.3} ) if $$specs{'txtQuantity3'};
				openprint::service::delete_service_spec( $Project->id(), $s_id, $key );

			} # end foreach
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutWidth1', $$specs{txtImageWidth}, ! exists $$specs{txtLayoutWidth1} ) if $$specs{'txtQuantity1'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutWidth2', $$specs{txtImageWidth}, ! exists $$specs{txtLayoutWidth2} ) if $$specs{'txtQuantity2'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutWidth3', $$specs{txtImageWidth}, ! exists $$specs{txtLayoutWidth3} ) if $$specs{'txtQuantity3'};
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtImageWidth' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutHeight1', $$specs{txtImageHeight}, ! exists $$specs{txtLayoutHeight1} ) if $$specs{'txtQuantity1'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutHeight2', $$specs{txtImageHeight}, ! exists $$specs{txtLayoutHeight2} ) if $$specs{'txtQuantity2'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutHeight3', $$specs{txtImageHeight}, ! exists $$specs{txtLayoutHeight3} ) if $$specs{'txtQuantity3'};
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtImageHeight' );
			foreach my $side ( 'SideOne','SideTwo' ) {
				foreach my $i ( 1 .. 8 ) {
					if ( $$specs{'chkSpecial'.$side.'Colour'.$i} and $$specs{'chkSpecial'.$side.'Colour'.$i} ne 'Y' ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, $$specs{'chkSpecial'.$side.'Colour'.$i}, 'Y' );
					} # end if
				} # end foreach
			} # end foreach
if ( $$specs{'ddmStockBrand'} eq 'Customer Supplied' ) {
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbSuppliedStock', 'Y' ) if ! $$specs{'rdbSuppliedStock'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbSpecificStock', 'Y' ) if ! $$specs{'rdbSpecificStock'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockBrand', $$specs{'ddmStockBrand'} ) if ! $$specs{'txtSpecificStockBrand'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockFinish', $$specs{'ddmStockFinish'} ) if ! $$specs{'txtSpecificStockFinish'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockColour', $$specs{'ddmStockColour'} ) if ! $$specs{'txtSpecificStockColour'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockWeight', $$specs{'ddmStockWeight'} ) if ! $$specs{'txtSpecificStockWeight'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtCustomMWeight', $$specs{'txtMWeight1'} ) if ! $$specs{'txtCustomMWeight'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'CustomStockPrice', '0.00' ) if ! $$specs{'CustomStockPrice'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockWidth', $$specs{'hdnSuppliedStockWidth1'} ) if ! $$specs{'txtSpecificStockWidth'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockHeight', $$specs{'hdnSuppliedStockHeight1'} ) if ! $$specs{'txtSpecificStockHeight'};

	if ( $$specs{'txtSpecificStockFinish'} =~ /matte/i ) {
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockGrade', 2 );
	} elsif ( $$specs{'txtSpecificStockFinish'} =~ /gloss/i ) {
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockGrade', 1 );
	} else {
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockGrade', 4 );
	} # end if
} # end if
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockType', 'Sheet' ) if ! $$specs{'StockType'};

				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPressSheetQty1', $$specs{'hdnGrossSheetCount1'}, ! exists $$specs{'txtPressSheetQty1'} ) if $$specs{'txtQuantity1'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPressSheetQty2', $$specs{'hdnGrossSheetCount2'}, ! exists $$specs{'txtPressSheetQty2'} ) if $$specs{'txtQuantity2'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPressSheetQty3', $$specs{'hdnGrossSheetCount3'}, ! exists $$specs{'txtPressSheetQty3'} ) if $$specs{'txtQuantity3'};
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnGrossSheetCount1' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnGrossSheetCount2' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnGrossSheetCount3' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnNetSheetCount1' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnNetSheetCount2' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnNetSheetCount3' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPressSheetQty' );
			
			foreach my $qty_index ( 1 .. 3 ) {
				my ($width, $height ) = split('x', $$specs{'ddmStockSheetSize'.$qty_index} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockWidth'.$qty_index, $width ) if $$specs{'txtQuantity'.$qty_index};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockHeight'.$qty_index, $height ) if $$specs{'txtQuantity'.$qty_index};
			} # end if
			foreach my $key ( 'Top','Bottom','Left','Right' ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'chkBleed'.$key, $key ) if ( ! $$specs{'chkBleed'.$key} ) and $$specs{'Bleed'.$key} eq 'true';
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'chkBleed'.$key, $key ) if $$specs{'chkBleed'.$key} eq 'true';
			} # end foreach
			foreach my $key ( 'hdnRequest','BleedTop','BleedBottom','BleedLeft','BleedRight','hdnSetupCost','hdnRunStyleCheck' ) {
				openprint::service::delete_service_spec( $Project->id(), $s_id, $key ) if exists $$specs{$key};
			} # end foreach
			if ( ! $$specs{'txtSpreadSize'} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpreadSize', $$p_specs{'txtSpreadSize'} );
			} # end if
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbColourBar', sets::isin($$specs{'rdbColourBar'},[ 'Yes','Y']) ? 'Y' : 'N' );

		foreach my $qty_index ( 1 .. 3 ) {	
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'SpreadRows'.$qty_index, $$specs{'ShapeRows'} );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'SpreadCols'.$qty_index, $$specs{'ShapeCols'} );
		} # end foreach

# Now if this signature has txtSignatureQty > 1, duplicate it, and adjust the price accordingly.
			if ( $$specs{'txtSignatureQuantity'} > 1 ) {
$log->debug("SPlitting Signatures");
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPrice1', $$specs{'txtPrice1'}/$$specs{'txtSignatureQuantity'} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPrice2', $$specs{'txtPrice2'}/$$specs{'txtSignatureQuantity'} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPrice3', $$specs{'txtPrice3'}/$$specs{'txtSignatureQuantity'} );
				$_ = q{SELECT MAX(strValue) FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='SignatureIndex'};
				my ( $sig_index ) = sql::execute( $log, $dbh, $_, $Project->id() );
				foreach my $blah ( 2 .. $$specs{'txtSignatureQuantity'} ) {
					my $new_service_index = openprint::print_project::insert_service( $log, $dbh, $Project->id(), 'AdditionalSignature' );
					my $new_specs = openprint::service::get_specs_ref( $Project->id(), $new_service_index );
					$sig_index += 1;
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $new_service_index, 'SignatureIndex', $sig_index );

					openprint::service::status( $Project->id(), $new_service_index, openprint::service::status( $Project->id(), $s_id ) );
					my $ac = sql::start_transaction( $dbh );
					foreach my $key ( keys %$specs ) {
						next if $key eq 'ServiceIndex';
						next if $key eq 'SignatureIndex';
						if ( $$specs{$key} and ( $$specs{$key} ne $$new_specs{$key} ) ) {
							openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $new_service_index, $key, $$specs{$key}, exists $$new_specs{$key} );
						} # end if
					} # end foreach
					openprint::service::delete_service_spec( $Project->id(), $new_service_index, 'txtSignatureQuantity' );
					sql::end_transaction( $dbh, $ac );
				} # end foreach
			} # end if
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtSignatureQuantity' ) if exists $$specs{'txtSignatureQuantity'};
		} # end foreach signature

		if ( $$p_specs{'rdbCover'} eq 'DifferentCover' ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $services{''}[0], 'rdbCover','Different' );
		} elsif ( $$p_specs{'rdbCover'} eq 'SelfCover' ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $services{''}[0], 'rdbCover','Self' );
		} # end if

		my $txtInteriorSpreadQuantity = $$p_specs{'txtTotalSpreadQuantity'} - $$p_specs{'txtGateFoldedSpreadQuantity'};
		if ( $$p_specs{'rdbCover'} eq 'Different' ) {
			if ( $$p_specs{'txtSpreadSize'} == 4 ) {
				$txtInteriorSpreadQuantity -= 1;
			} else {
				$txtInteriorSpreadQuantity -= 2;
			} # end if
		} # end if
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $services{''}[0], 'txtInteriorSpreadQuantity',$txtInteriorSpreadQuantity );

		# Do some cleanup...
		foreach my $key ( 'rdbRandomProof','txtCropMarkSpace','ScreenType','rdbCardboardBacking','BleedSize','ddmBleedSize','rdbPressProof','BleedRight','BleedLeft','BleedTop','BleedBottom','rdbWaxFree','rdbGripWidth','rdbPlates','rdbAqueousSideOne','NewBook','rdbAqueousSideTwo','rdbGripHeight' ) {
			openprint::service::delete_service_spec( $Project->id(), $services{''}[0], $key ) if exists $$p_specs{$key};
		} # end foreach


	} else {
		my $s_id = $services{''}[0];
		if ( $s_id ) {
		my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtQuantity1', $Project->quantity1() ) if $Project->quantity1();
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtQuantity2', $Project->quantity2() ) if $Project->quantity2();
		openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtQuantity3', $Project->quantity3() ) if $Project->quantity3();
			if ( exists $$specs{'BleedSize1'} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ddmBleedSize1', $$specs{'BleedSize1'});
			} 
			if ( exists $$specs{'BleedSize2'} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ddmBleedSize2', $$specs{'BleedSize2'});
			} 
			if ( exists $$specs{'BleedSize3'} ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ddmBleedSize3', $$specs{'BleedSize3'});
			} 
			if ( exists $$specs{'BleedSize'} ) {
				foreach my $qty_index ( 1 .. 3 ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ddmBleedSize'.$qty_index, $$specs{'BleedSize'} ) if $$specs{'txtQuantity'.$qty_index};
				} # end 
			} # end 
		foreach my $key ( 'ddmRunStyle','ddmPress','ddmBleedSize','txtSignatureSpreadQuantity','txtUnspecifiedSpreadQuantity','ddmStockSheetSize','rdbPlateType','txtPlateQuantity','txtImposition','hdnImpositionRows','hdnImpositionColumns','chkOverrideRunStyle','chkOverridePress','hdnImageOrientation','txtMWeight','rdbGrainDirection','hdnSuppliedStockWidth','hdnSuppliedStockHeight','txtPlateChangeQuantity') {
			next if ! exists $$specs{$key};
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, $key.'1', $$specs{$key}, ! exists $$specs{$key.1} ) if $$specs{'txtQuantity1'};
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, $key.'2', $$specs{$key}, ! exists $$specs{$key.2} ) if $$specs{'txtQuantity2'};
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, $key.'3', $$specs{$key}, ! exists $$specs{$key.3} ) if $$specs{'txtQuantity3'};
				openprint::service::delete_service_spec( $Project->id(), $s_id, $key );
		} # end foreach
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutWidth1', $$specs{txtImageWidth}, ! exists $$specs{txtLayoutWidth1} ) if $$specs{'txtQuantity1'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutWidth2', $$specs{txtImageWidth}, ! exists $$specs{txtLayoutWidth2} ) if $$specs{'txtQuantity2'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutWidth3', $$specs{txtImageWidth}, ! exists $$specs{txtLayoutWidth3} ) if $$specs{'txtQuantity3'};
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtImageWidth' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutHeight1', $$specs{txtImageHeight}, ! exists $$specs{txtLayoutHeight1} ) if $$specs{'txtQuantity1'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutHeight2', $$specs{txtImageHeight}, ! exists $$specs{txtLayoutHeight2} ) if $$specs{'txtQuantity2'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtLayoutHeight3', $$specs{txtImageHeight}, ! exists $$specs{txtLayoutHeight3} ) if $$specs{'txtQuantity3'};
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtImageHeight' );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPressSheetQty1', $$specs{'hdnGrossSheetCount1'}, ! exists $$specs{'txtPressSheetQty1'} ) if $$specs{'txtQuantity1'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPressSheetQty2', $$specs{'hdnGrossSheetCount2'}, ! exists $$specs{'txtPressSheetQty2'} ) if $$specs{'txtQuantity2'};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPressSheetQty3', $$specs{'hdnGrossSheetCount3'}, ! exists $$specs{'txtPressSheetQty3'} ) if $$specs{'txtQuantity3'};
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnGrossSheetCount1' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnGrossSheetCount2' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnGrossSheetCount3' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnNetSheetCount1' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnNetSheetCount2' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnNetSheetCount3' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPressSheetQty' );
			foreach my $side ( 'SideOne','SideTwo' ) {
				foreach my $i ( 1 .. 8 ) {
					if ( $$specs{'chkSpecial'.$side.'Colour'.$i} and $$specs{'chkSpecial'.$side.'Colour'.$i} ne 'Y' ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, $$specs{'chkSpecial'.$side.'Colour'.$i}, 'Y' );
					} # end if
				} # end foreach
			} # end foreach
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbColourBar', sets::isin($$specs{'rdbColourBar'},[ 'Yes','Y']) ? 'Y' : 'N' );
			foreach my $qty_index ( 1 .. 3 ) {
				my ($width, $height ) = split('x', $$specs{'ddmStockSheetSize'.$qty_index} );
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockWidth'.$qty_index, $width ) if $$specs{'txtQuantity'.$qty_index};
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockHeight'.$qty_index, $height ) if $$specs{'txtQuantity'.$qty_index};
			} # end if
if ( $$specs{'ddmStockBrand'} eq 'Customer Supplied' ) {
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbSuppliedStock', 'Y' ) if ! $$specs{'rdbSuppliedStock'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbSpecificStock', 'Y' ) if ! $$specs{'rdbSpecificStock'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockBrand', $$specs{'ddmStockBrand'} ) if ! $$specs{'txtSpecificStockBrand'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockFinish', $$specs{'ddmStockFinish'} ) if ! $$specs{'txtSpecificStockFinish'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockColour', $$specs{'ddmStockColour'} ) if ! $$specs{'txtSpecificStockColour'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockWeight', $$specs{'ddmStockWeight'} ) if ! $$specs{'txtSpecificStockWeight'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtCustomMWeight', $$specs{'txtMWeight1'} ) if ! $$specs{'txtCustomMWeight'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockWidth', $$specs{'hdnSuppliedStockWidth1'} ) if ! $$specs{'txtSpecificStockWidth'};
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSpecificStockHeight', $$specs{'hdnSuppliedStockHeight1'} ) if ! $$specs{'txtSpecificStockHeight'};
} # end if
	openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtSignatureQuantity' );
	openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'StockType', 'Sheet' ) if ! $$specs{'StockType'};
			foreach my $key ( 'Top','Bottom','Left','Right' ) {
				openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'chkBleed'.$key, $key, ! exists $$specs{'chkBleed'.$key} ) if ( ! $$specs{'chkBleed'.$key} ) and $$specs{'Bleed'.$key} eq 'true';
			} # end foreach
			foreach my $key ( 'hdnRequest','BleedSize','BleedTop','BleedBottom','BleedLeft','BleedRight','hdnSetupCost','hdnRunStyleCheck' ) {
				openprint::service::delete_service_spec( $Project->id(), $s_id, $key ) if exists $$specs{$key};
			} # end foreach
	} # end if
	} # end if
	sql::end_transaction( $dbh, $ac );

	# Update plain cartons, etc
	if ( $services{'PlainCartons'} ) {
	my $ac = sql::start_transaction( $dbh );
		foreach my $s_id ( @{$services{'PlainCartons'}} ) {
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtItemsPerPackage', $$specs{'txtItemsPerPackage1'}, ! exists $$specs{'txtItemsPerPackage'} ) if! $$specs{'txtItemsPerPackage'};
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage1' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage2' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage3' );

			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPackageWeight', $$specs{'txtPackageWeight1'}, ! exists $$specs{'txtPackageWeight'} ) if ! $$specs{'txtPackageWeight'};
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight1' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight2' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight3' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity1' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity2' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity3' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtFinishedWeight', $$specs{'hdnProjectWeight'}, ! exists $$specs{'txtFinishedWeight'} );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnProjectWeight' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight1', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity1'}, ! exists $$specs{'txtFinishedWeight'} );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight2', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity2'}, ! exists $$specs{'txtFinishedWeight'} );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight3', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity3'}, ! exists $$specs{'txtFinishedWeight'} );
		} # end foreach
	sql::end_transaction( $dbh, $ac );
	} # end if
	if ( $services{'BulkSkids'} ) {
	my $ac = sql::start_transaction( $dbh );
		foreach my $s_id ( @{$services{'BulkSkids'}} ) {
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtItemsPerPackage', $$specs{'txtItemsPerPackage1'}, 1 ) if ! $$specs{'txtItemsPerPackage1'};
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage1' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage2' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtItemsPerPackage3' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPackageWeight', $$specs{'txtPackageWeight1'}, 1 ) if ! $$specs{'txtPackageWeight1'};
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight1' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight2' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtPackageWeight3' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity1' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity2' );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnSkidQuantity3' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtFinishedWeight', $$specs{'hdnProjectWeight'}, 1 );
			openprint::service::delete_service_spec( $Project->id(), $s_id, 'hdnProjectWeight' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight1', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity1'}, ! exists $$specs{'txtFinishedWeight'} );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight2', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity2'}, ! exists $$specs{'txtFinishedWeight'} );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'totalWeight3', $$specs{'txtFinishedWeight'}*$$specs{'txtQuantity3'}, ! exists $$specs{'txtFinishedWeight'} );
		} # end foreach

		sql::end_transaction( $dbh, $ac );
	} # end if
	if ( $services{'Folding'} ) {
		foreach my $s_id ( @{$services{'Folding'}} ) {
			my $ac = sql::start_transaction( $dbh );
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
			foreach my $fold ( keys %openprint::Estimating::Folding::fold_types ) {
				foreach my $qty_index ( 1 .. 3 ) {
					if ( $$specs{'chkOverride-txt'.$fold.'Qty'} eq 'Y' ) {
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "chkOverrideFoldType-0-$qty_index", $$specs{'chkOverride-txt'.$fold.'Qty'} );
					} # end if
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "$fold-Qty-0-$qty_index", $$specs{'txt'.$fold.'Qty'} );
					my @Equipment = openprint::Equipment::find( 'strid'=>$$specs{'ddmEquipment'.$qty_index} );
					if ( @Equipment ) {
						my $Equipment = shift @Equipment;
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "ddmEquipment-0-$qty_index", $Equipment->id() );
						openprint::service::delete_service_spec( $Project->id(), $s_id, 'ddmEquipment'.$qty_index );
					} # end if
				} # end foreach
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'chkOverride-txt'.$fold.'Qty' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'txt'.$fold.'Qty' );

			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} # end foreach
	} # end if
	if ( $services{'Perforating'} ) {
		foreach my $s_id ( @{$services{'Perforating'}} ) {
			my $ac = sql::start_transaction( $dbh );
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
				foreach my $qty_index ( 1 .. 3 ) {
					next if ! $$specs{'txtQuantity'.$qty_index};
					foreach my $ss_id ( $Project->signatures() ) {
						my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $ss_id );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'ddmEquipment'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtImposition-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImposition'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtLayoutWidth-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImageWidth'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtLayoutHeight-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImageHeight'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
					} # end foreach
				} # end foreach
			sql::end_transaction( $dbh, $ac );
		} # end foreach
	} # end if
	if ( $services{'Scoring'} ) {
		foreach my $s_id ( @{$services{'Scoring'}} ) {
			my $ac = sql::start_transaction( $dbh );
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
				foreach my $qty_index ( 1 .. 3 ) {
					foreach my $ss_id ( $Project->signatures() ) {
						my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $ss_id );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "ddmEquipment-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'ddmEquipment'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtImposition-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImposition'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtLayoutWidth-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImageWidth'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
						openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtLayoutHeight-$$sig_specs{SignatureIndex}-$qty_index", $$specs{'txtImageHeight'.$qty_index.'-'. $$sig_specs{SignatureIndex}} );
					} # end foreach
				} # end foreach
			sql::end_transaction( $dbh, $ac );
		} # end foreach
	} # end if
	if ( $services{'Cutting'} ) {
		foreach my $s_id ( @{$services{'Cutting'}} ) {
			my $ac = sql::start_transaction( $dbh );
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
			foreach my $ss_id ( $Project->signatures() ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $ss_id );
				foreach my $qty_index ( 1 .. 3 ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, "txtCalculatedCuts-$$sig_specs{'SignatureIndex'}-$qty_index", $$specs{"txtCalculatedCuts$$sig_specs{'SignatureIndex'}"} );
				} # end foreach
			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} # end foreach
	} # end if
	if ( $services{'SaddleStitching'} ) {
		foreach my $s_id ( @{$services{'SaddleStitching'}} ) {
			my $ac = sql::start_transaction( $dbh );
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
			foreach my $qty_index ( 1 .. 3 ) {
				foreach my $pages ( 4, 8, 12, 16, 20, 24, 32 ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSignatureQty'.$pages.'Page-'.$qty_index, $$specs{'txtSignatureQty'.$pages.'Page'} );
				} # end foreach

			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} # end foreach
	} # end if
	if ( $services{'LoopStitching'} ) {
		foreach my $s_id ( @{$services{'SaddleStitching'}} ) {
			my $ac = sql::start_transaction( $dbh );
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
			foreach my $qty_index ( 1 .. 3 ) {
				foreach my $pages ( 4, 8, 12, 16, 20, 24, 32 ) {
					openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtSignatureQty'.$pages.'Page-'.$qty_index, $$specs{'txtSignatureQty'.$pages.'Page'} );
				} # end foreach

			} # end foreach
			sql::end_transaction( $dbh, $ac );
		} # end foreach
	} # end if
	if ( $services{'Bundling'} ) {
		foreach my $s_id ( @{$services{'Bundling'}} ) {
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'ServiceType', 'Bundling' );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtItemsPerPackage', $$specs{'txtWrapQuantity'} );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbCardboardBacking', 'N' );
			my @qtys = split(',', $$specs{'txtQuantity'} );
			foreach my $qty_index ( 1 .. 3 ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPackageQuantity'.$qty_index, $qtys[$qty_index-1] );
			} # end foreach
				
		} # end foreach
	} #Ne dif
	if ( $services{'ShrinkWrap'} ) {
		foreach my $s_id ( @{$services{'ShrinkWrap'}} ) {
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtItemsPerPackage', $$specs{'txtWrapQuantity'} );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbCardboardBacking', 'N' );
			my @qtys = split(',', $$specs{'txtQuantity'} );
			foreach my $qty_index ( 1 .. 3 ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPackageQuantity'.$qty_index, $qtys[$qty_index-1] );
			} # end foreach
		} # end foreach
	} #Ne dif
	if ( $services{'KraftWrap'} ) {
		foreach my $s_id ( @{$services{'KraftWrap'}} ) {
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtItemsPerPackage', $$specs{'txtWrapQuantity'} );
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'rdbCardboardBacking', 'N' );
			my @qtys = split(',', $$specs{'txtQuantity'} );
			foreach my $qty_index ( 1 .. 3 ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'txtPackageQuantity'.$qty_index, $qtys[$qty_index-1] );
			} # end foreach
		} # end foreach
	} #Ne dif
	if ( $services{'Scanning'} ) {
		foreach my $s_id ( @{$services{'Scanning'}} ) {
			my $specs = openprint::service::get_specs_ref( $Project->id(), $s_id );
			if ( exists $$specs{'ddmLineScreen'} or exists $$specs{'txtLineScreenOther'} ) {
			openprint::service::insert_service_spec( $log, $dbh, $Project->id(), $s_id, 'LineScreen', $$specs{'ddmLineScreen'} ? $$specs{'ddmLineScreen'} : $$specs{'txtLineScreenOther'} );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'ddmLineScreen' );
				openprint::service::delete_service_spec( $Project->id(), $s_id, 'txtLineScreenOther' );
			} # end if
		} # end foreach
	} #Ne dif

	# Do this after every project to keep the cache from growing out of control
	openprint::service::init_cache();

} # end foreach Project
1;
__END__
