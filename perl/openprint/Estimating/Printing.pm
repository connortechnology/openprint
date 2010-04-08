# Copyright (C) 2007 Isaac Connor <isaac@connortechnology.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA

package openprint::Estimating::Printing;
my $threading = 0;
my $debug = 0;
my $master_time;

my %folding_cache;
my %Papers;
# indexed by press
my %impositions;
my $max_recursion_depth = 3;
my %signature_price_cache;
my $use_signature_price_cache = 1;
my %converted_imposition_cache;
my $use_converted_imposition_cache = 1;
my %filtered_imposition_cache;
my $use_filtered_imposition_cache = 1;


use strict;
#use warnings;
use POSIX qw(ceil);
use openprint ();
use vars qw( %config $log $dbh );
*config = \%openprint::config;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require misc;
require openprint::print_project;
require openprint::service;
require openprint::Equipment;
require openprint::imposition;
require openprint::Paper;
require openprint::Estimating::Paper;
require openprint::Estimating::Folding;
require openprint::Estimating::Scoring;
require openprint::Estimating::Perforating;
require openprint::Estimating::Cutting;
require openprint::Estimating::Stitching;
require openprint::Estimating::SpinePaste;
require openprint::Estimating::UVCoating;
require openprint::Estimating::Aqueous;
require openprint::Estimating::Numbering;
require openprint::Estimating::Proofs;
require openprint::Equipment;
require openprint::Material;
use Time::HiRes qw{ time gettimeofday tv_interval }; 

# These are use to tell the code which variables to save
# There are other values in teh actual specs hash, but htey are either transitory or should never be changed
my %variables = (
		'Impositions'=>[], 'Additional Impositions1'=>[], 'Additional Impositions2'=>[], 'Additional Impositions3'=>[],
		'hdnBreakdown1'=>['save','output'], 'hdnBreakdown2'=>['save','output'], 'hdnBreakdown3'=>['save','output'],
		'txtSignatureType' => ['save'],
		'txtServiceDescription'	=> ['save'],
		'txtEmployeeComments'	=>	['save'],
		'txtPrice1' => ['save','output'], 'txtPrice2' => ['save','output'], 'txtPrice3' => ['save','output'],
		'Markup1' => ['save'], 'Markup2' => ['save'], 'Markup3' => ['save'],
		'OverridePrice1' => ['save'], 'OverridePrice2' => ['save'], 'OverridePrice3' => ['save'],
		'MPrice1' => ['save','output'], 'MPrice2' => ['save','output'], 'MPrice3' => ['save','output'],
		'chkCyanSideOne' => ['save'],
		'chkMagentaSideOne' => ['save'],
		'chkYellowSideOne'	=> ['save'],
		'chkBlackSideOne' 	=> ['save'],
		'chkProcessColourSideOne' 		=>	['save'],
		'CyanSpotSideOneCoverage'		=>	['save'],
		'MagentaSpotSideOneCoverage'	=>	['save'],
		'YellowSpotSideOneCoverage'		=>	['save'],
		'BlackSpotSideOneCoverage'		=>	['save'],

		'CyanSideOneCoverage'	=>	['save'],
		'MagentaSideOneCoverage'	=>	['save'],
		'YellowSideOneCoverage'	=>	['save'],
		'BlackSideOneCoverage'	=>	['save'],
		'chkColourCoating1SideOne' => ['save'], 'ColourCoatingType1SideOne' => ['save'], 'ColourCoatingColour1SideOne' => ['save'],'ColourCoatingCoverage1SideOne' => ['save'],
		'chkColourCoating2SideOne' => ['save'], 'ColourCoatingType2SideOne' => ['save'], 'ColourCoatingColour2SideOne' => ['save'],'ColourCoatingCoverage2SideOne' => ['save'],
		'chkColourCoating3SideOne' => ['save'], 'ColourCoatingType3SideOne' => ['save'], 'ColourCoatingColour3SideOne' => ['save'],'ColourCoatingCoverage3SideOne' => ['save'],
		'chkColourCoating4SideOne' => ['save'], 'ColourCoatingType4SideOne' => ['save'], 'ColourCoatingColour4SideOne' => ['save'],'ColourCoatingCoverage4SideOne' => ['save'],
		'chkColourCoating5SideOne' => ['save'], 'ColourCoatingType5SideOne' => ['save'], 'ColourCoatingColour5SideOne' => ['save'],'ColourCoatingCoverage5SideOne' => ['save'],
		'chkColourCoating6SideOne' => ['save'], 'ColourCoatingType6SideOne' => ['save'], 'ColourCoatingColour6SideOne' => ['save'],'ColourCoatingCoverage6SideOne' => ['save'],
		'chkColourCoating7SideOne' => ['save'], 'ColourCoatingType7SideOne' => ['save'], 'ColourCoatingColour7SideOne' => ['save'],'ColourCoatingCoverage7SideOne' => ['save'],
		'chkColourCoating8SideOne' => ['save'], 'ColourCoatingType8SideOne' => ['save'], 'ColourCoatingColour8SideOne' => ['save'],'ColourCoatingCoverage8SideOne' => ['save'],
		'chkColourCoating9SideOne' => ['save'], 'ColourCoatingType9SideOne' => ['save'], 'ColourCoatingColour9SideOne' => ['save'],'ColourCoatingCoverage9SideOne' => ['save'],

		'CyanSpotSideTwoCoverage'	=>	['save'],
		'MagentaSpotSideTwoCoverage'	=>	['save'],
		'YellowSpotSideTwoCoverage'	=>	['save'],
		'BlackSpotSideTwoCoverage'	=>	['save'],

		'CyanSideTwoCoverage'	=>	['save'],
		'MagentaSideTwoCoverage'	=>	['save'],
		'YellowSideTwoCoverage'	=>	['save'],
		'BlackSideTwoCoverage'	=>	['save'],

		'chkCyanSideTwo' => ['save'],'chkMagentaSideTwo' => ['save'],'chkYellowSideTwo' => ['save'],'chkBlackSideTwo' => ['save'],
		'chkProcessColourSideTwo' => ['save'],
		'chkColourCoating1SideTwo' => ['save'], 'ColourCoatingType1SideTwo' => ['save'], 'ColourCoatingColour1SideTwo' => ['save'],'ColourCoatingCoverage1SideTwo' => ['save'],
		'chkColourCoating2SideTwo' => ['save'], 'ColourCoatingType2SideTwo' => ['save'], 'ColourCoatingColour2SideTwo' => ['save'],'ColourCoatingCoverage2SideTwo' => ['save'],
		'chkColourCoating3SideTwo' => ['save'], 'ColourCoatingType3SideTwo' => ['save'], 'ColourCoatingColour3SideTwo' => ['save'],'ColourCoatingCoverage3SideTwo' => ['save'],
		'chkColourCoating4SideTwo' => ['save'], 'ColourCoatingType4SideTwo' => ['save'], 'ColourCoatingColour4SideTwo' => ['save'],'ColourCoatingCoverage4SideTwo' => ['save'],
		'chkColourCoating5SideTwo' => ['save'], 'ColourCoatingType5SideTwo' => ['save'], 'ColourCoatingColour5SideTwo' => ['save'],'ColourCoatingCoverage5SideTwo' => ['save'],
		'chkColourCoating6SideTwo' => ['save'], 'ColourCoatingType6SideTwo' => ['save'], 'ColourCoatingColour6SideTwo' => ['save'],'ColourCoatingCoverage6SideTwo' => ['save'],
		'chkColourCoating7SideTwo' => ['save'], 'ColourCoatingType7SideTwo' => ['save'], 'ColourCoatingColour7SideTwo' => ['save'],'ColourCoatingCoverage7SideTwo' => ['save'],
		'chkColourCoating8SideTwo' => ['save'], 'ColourCoatingType8SideTwo' => ['save'], 'ColourCoatingColour8SideTwo' => ['save'],'ColourCoatingCoverage8SideTwo' => ['save'],
		'chkColourCoating9SideTwo' => ['save'], 'ColourCoatingType9SideTwo' => ['save'], 'ColourCoatingColour9SideTwo' => ['save'],'ColourCoatingCoverage9SideTwo' => ['save'],
		'sides_the_same'	=> ['save'],
		'ddmBleedSize1' => ['save','output'], 'ddmBleedSize2' => ['save','output'], 'ddmBleedSize3' => ['save','output'],
		'chkOverrideBleedSize1'=>['save'], 'chkOverrideBleedSize2'=>['save'], 'chkOverrideBleedSize3'=>['save'],

		'BleedLeft' => ['save'], 'BleedRight' => ['save'], 'BleedTop' => ['save'], 'BleedBottom' => ['save'],
		'rdbColourBar' => ['save','output'], 'txtCropMarkSpace' => ['save'],
		'ddmStockBrand' => ['save'], 'txtSpecificStockBrand' => ['save'], 'ddmStockFinish' => ['save'], 'txtSpecificStockFinish' => ['save'], 'ddmStockColour' => ['save'], 'txtSpecificStockColour' => ['save'],

		'ddmStockWeight' => ['save'], 'txtSpecificStockWeight'=>['save'],
		'txtSpecificStockCalliper' => ['save','output'], 'txtSpecificStockWidth' => ['save'], 'txtSpecificStockHeight' => ['save'], 'CustomSheetDoubleSided' => ['save'], 'CustomStockPrice' => ['save'],'txtCustomMWeight' => ['save'],'txtStockGSM' => ['save','output'],
		'perfecting'=>['save'],
		'basis_width'=>['save'],'basis_height'=>['save'],'basis_mweight'=>['save'],
		'StockGrade'	=> ['save'],	
		'txtUnspecifiedPageQuantity1' => ['output'], 'PageQuantity1' => ['save','output'],
		'txtUnspecifiedPageQuantity2' => ['output'], 'PageQuantity2' => ['save','output'],
		'txtUnspecifiedPageQuantity3' => ['output'], 'PageQuantity3' => ['save','output'],
		'minimum_order'=>['save'],'sheets_per_package'=>['save'],'full_packages'=>['save'],
		'chkOverridePageQuantity1' => ['save'], 'chkOverridePageQuantity2' => ['save'], 'chkOverridePageQuantity3' => ['save'],
		'SpreadRows1' => ['save','output'],'SpreadCols1' => ['save','output'],
		'SpreadRows2' => ['save','output'],'SpreadCols2' => ['save','output'],
		'SpreadRows3' => ['save','output'],'SpreadCols3' => ['save','output'],
		'ddmStockSheetSize' => ['save'],'ddmStockSheetSize1' => ['save','output'], 'ddmStockSheetSize2' => ['save','output'], 'ddmStockSheetSize3' => ['save','output'],
		'ddmRunStyle'=>['save'],'ddmRunStyle1' => ['save','output'], 'ddmRunStyle2' => ['save','output'], 'ddmRunStyle3' => ['save','output'],
		'ddmPress1' => ['save','output'], 'ddmPress2' => ['save','output'], 'ddmPress3' => ['save','output'], 
		'PrintingType1' => ['save','output'], 'PrintingType2' => ['save','output'], 'PrintingType3' => ['save','output'], 
		'PrintingTypes' => [],

		'rdbPlateType1' => ['save','output'], 'rdbPlateType2' => ['save','output'], 'rdbPlateType3' => ['save','output'],
		'PlateID1' => ['save','output'], 'PlateID2' => ['save','output'], 'PlateID3' => ['save','output'],
		'txtPlateQuantity1' => ['save','output'], 'txtPlateQuantity2' => ['save','output'], 'txtPlateQuantity3' => ['save','output'], 
		'BlankPlateQuantity1' => ['save','output'], 'BlankPlateQuantity2' => ['save','output'], 'BlankPlateQuantity3' => ['save','output'], 
		'txtPlateChangeQuantity1' => ['save'], 'txtPlateChangeQuantity2' => ['save'], 'txtPlateChangeQuantity3' => ['save'], 
#
		'PerPlateCost1' => ['save','output'], 'PerPlateCost2' => ['save','output'], 'PerPlateCost3' => ['save','output'],
		'PlateTotalCost1' => ['save','output'], 'PlateTotalCost2'  => ['save','output'], 'PlateTotalCost3' => ['save','output'],
		'PlateMakeReady1' =>  ['save','output'], 'PlateMakeReady2' => ['save','output'], 'PlateMakeReady3' => ['save','output'],
		'PerPlateMkRd1' =>  ['save','output'], 'PerPlateMkRd2' => ['save','output'], 'PerPlateMkRd3' => ['save','output'],
		'RunChargeTotal1' =>  ['save','output'], 'RunChargeTotal2' => ['save','output'], 'RunChargeTotal3' => ['save','output'],
		'OverBase1' =>  ['save','output'], 'OverBase2' => ['save','output'], 'OverBase3' => ['save','output'],
		'OverSetup1' =>  ['save','output'], 'OverSetup2' => ['save','output'], 'OverSetup3' => ['save','output'],
		'OverRun1' =>  ['save','output'], 'OverRun2' => ['save','output'], 'OverRun3' => ['save','output'],
		'OverTotal1' =>  ['save','output'], 'OverTotal2' => ['save','output'], 'OverTotal3' => ['save','output'],
		'PressWashPrice1' =>  ['save','output'], 'PressWashPrice2' => ['save','output'], 'PressWashPrice3' => ['save','output'],
		'PressWashCharge1' =>  ['save','output'], 'PressWashCharge2' => ['save','output'], 'PressWashCharge3' => ['save','output'],
		'PressWashes1' =>  ['save','output'], 'PressWashes2' => ['save','output'], 'PressWashes3' => ['save','output'],
		'ImpositionCharge1' =>  ['save','output'], 'ImpositionCharge2' => ['save','output'], 'ImpositionCharge3' => ['save','output'],
		'PageCharge1' =>  ['save','output'], 'PageCharge2' => ['save','output'], 'PageCharge3' => ['save','output'],
		'SteppingCharge1' =>  ['save','output'], 'SteppingCharge2' => ['save','output'], 'SteppingCharge3' => ['save','output'],
		'InkTotalCharge1' =>  ['save','output'], 'InkTotalCharge2' => ['save','output'], 'InkTotalCharge3' => ['save','output'],
		'InkMixCharge1' =>  ['save','output'], 'InkMixCharge2' => ['save','output'], 'InkMixCharge3' => ['save','output'],
		'Roll2SheetCharge1'	=> ['save','output'], 'Roll2SheetCharge2'	=> ['save','output'], 'Roll2SheetCharge3'	=> ['save','output'],
#

		'txtPressSheetQty1' => ['save','output'], 'txtPressSheetQty2' => ['save','output'], 'txtPressSheetQty3' => ['save','output'],
		'chkOverrideImposition1' => ['save'], 'chkOverrideImposition2' => ['save'], 'chkOverrideImposition3' => ['save'],
		'txtImposition'=>['save'],'txtImposition1' => ['save','output'], 'txtImposition2' => ['save','output'], 'txtImposition3' => ['save','output'],
		'txtImageWidth1' => ['save','output'], 'txtImageWidth2' => ['save','output'], 'txtImageWidth3' => ['save','output'],
		'txtImageHeight1' => ['save','output'], 'txtImageHeight2' => ['save','output'], 'txtImageHeight3' => ['save','output'],
		'txtLayoutWidth1' => ['save','output'], 'txtLayoutWidth2' => ['save','output'], 'txtLayoutWidth3' => ['save','output'],
		'txtLayoutHeight1' => ['save','output'], 'txtLayoutHeight2' => ['save','output'], 'txtLayoutHeight3' => ['save','output'],
		'hdnImpositionRows'=>['save'],'hdnImpositionRows1' => ['save','output'], 'hdnImpositionRows2' => ['save','output'], 'hdnImpositionRows3' => ['save','output'],
		'hdnImpositionColumns'=>['save'],'hdnImpositionColumns1' => ['save','output'], 'hdnImpositionColumns2' => ['save','output'], 'hdnImpositionColumns3' => ['save','output'],
		'hdnImpositionDutchRows'=>['save'],'hdnImpositionDutchRows1' => ['save','output'], 'hdnImpositionDutchRows2' => ['save','output'], 'hdnImpositionDutchRows3' => ['save','output'],
		'hdnImpositionDutchColumns'=>['save'],'hdnImpositionDutchColumns1' => ['save','output'], 'hdnImpositionDutchColumns2' => ['save','output'], 'hdnImpositionDutchColumns3' => ['save','output'],
		'txtQuantity1' => ['save'], 'txtQuantity2' => ['save'], 'txtQuantity3' => ['save'], 
		'hdnImpressionQuantity1' => ['save','output'], 'hdnImpressionQuantity2' => ['save','output'], 'hdnImpressionQuantity3' => ['save','output'], 
		'rdbPressProof' => ['save'], 
		'txtMWeight1' => ['save','output'], 'txtMWeight2' => ['save','output'], 'txtMWeight3' => ['save','output'],
		'paper_id1'	=>	['save','output'], 'paper_id2'	=>	['save','output'], 'paper_id3'	=> ['save','output'],
		'hdnSuppliedStockWidth1' => ['save','output'], 'hdnSuppliedStockWidth2' => ['save','output'], 'hdnSuppliedStockWidth3' => ['save','output'],
		'hdnSuppliedStockHeight1' => ['save','output'], 'hdnSuppliedStockHeight2' => ['save','output'], 'hdnSuppliedStockHeight3' => ['save','output'],
		'StockWidth'=>['save'],'StockWidth1' => ['save','output'], 'StockWidth2' => ['save','output'], 'StockWidth3' => ['save','output'],
		'StockHeight'=>['save'],'StockHeight1' => ['save','output'], 'StockHeight2' => ['save','output'], 'StockHeight3' => ['save','output'],
		'OverrideStockWidth1' => ['save'], 'OverrideStockWidth2' => ['save'], 'OverrideStockWidth3' => ['save'],
		'OverrideStockHeight1' => ['save'], 'OverrideStockHeight2' => ['save'], 'OverrideStockHeight3' => ['save'],
		'CutOff1' => ['save','output'], 'CutOff2' => ['save','output'], 'CutOff3' => ['save','output'],
		'OverrideCutOff1' => ['save'], 'OverrideCutOff2' => ['save'], 'OverrideCutOff3' => ['save'],
		'StockType' => ['save','output'],'StockType1' => ['save','output'], 'StockType2' => ['save','output'], 'StockType3' => ['save','output'],
		'OverrideStockType1'	=>	['save'], 'OverrideStockType2'	=>	['save'], 'OverrideStockType3'	=>	['save'],
		'hdnImageOrientation1' => ['save','output'], 'hdnImageOrientation2' => ['save','output'], 'hdnImageOrientation3' => ['save','output'], 
		'hdnNetSheetCount1' => ['save','output'], 'hdnNetSheetCount2' => ['save','output'], 'hdnNetSheetCount3' => ['save','output'],
		'StockQuantity1' => ['save','output'], 'StockQuantity2' => ['save','output'], 'StockQuantity3' => ['save','output'],
		'RunTime1' => ['save','output'], 'RunTime2' => ['save','output'], 'RunTime3' => ['save','output'],
		'txtWidth' => ['save'], 'txtHeight' => ['save'], 'txtFinalWidth' => ['save'], 'txtFinalHeight' => ['save'],
		'chkOverrideDimensions'	=> ['save'],
		'txtFinishedCalliper' => ['save','output'], 
		'PageQuantity' => ['save'], # for Scratch Pads
# Presentation Folders
		'rdbPanels' => ['save'],'PocketSize' => ['save'],'chkPocketLeft' => ['save'],'chkPocketCenter' => ['save'],'chkPocketRight' => ['save'],
		'rdbSuppliedStock' => ['save'], 'rdbSpecificStock' => ['save'],'rdbTemplateType' => ['save'],
		'chkOverrideRunStyle1' => ['save'], 'chkOverrideRunStyle2' => ['save'], 'chkOverrideRunStyle3' => ['save'],
		'chkOverrideSheetSize1' => ['save'], 'chkOverrideSheetSize2' => ['save'], 'chkOverrideSheetSize3' => ['save'],
		'chkOverridePress1' => ['save'], 'chkOverridePress2' => ['save'], 'chkOverridePress3' => ['save'],
		'OverridePrintingType1' => ['save'], 'OverridePrintingType2' => ['save'], 'OverridePrintingType3' => ['save'],
		'Versions' => ['save'],
		'versions' => ['save'],
		'ddmProjectSize' => ['save'],
		'ScreenType' => ['save'],
		'rdbGrainDirection1' => ['save','output'], 'rdbGrainDirection2' => ['save','output'], 'rdbGrainDirection3' => ['save','output'],
		'chkOverrideGrainDirection1' => ['save'], 'chkOverrideGrainDirection2' => ['save'], 'chkOverrideGrainDirection3' => ['save'],
		'txtPressSheetComboItems'=>['save'],
		'txtSpreadSize' => ['save'],
		'Group' => ['save'], 'GroupPageQuantity' => ['save'],
		'PaperMessage1'=>['output'], 'PaperMessage2'=>['output'], 'PaperMessage3'=>['output'],

		# These two are for when the customer is supplying the pages. The first just says whether the pages are supplied, the second tells us whether they are supplying sheets or folded signatures.
		'pages_supplied'=>['save'],
		'supplied_format'=>['save'],
# Banners
		'grommets' => ['save'],
		);

sub variables {
	my ( $project_index, $service_index, $specs, $new_specs ) = @_;

	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k if sets::isin( 'save', $variables{$k} );
	} # end foreach;

	foreach my $side ( 'SideOne','SideTwo' ) {
		foreach my $k ( keys %$new_specs ) {
#$openprint::log->debug("Variables: $side $k old: $$specs{$k} new: $$new_specs{$k}");
			if ( my ( $index ) = $k =~ /ColourCoating(\d+)$side/ ) {
#$openprint::log->debug("Saving $side $k $$new_specs{$k} $index");
				push @v, 'chkColourCoating'.$index.$side;
				push @v, 'ColourCoatingType'.$index.$side;
				push @v, 'ColourCoatingColour'.$index.$side;
				push @v, 'ColourCoatingCoverage'.$index.$side;
			} # end if
		} # end foreach k
	} # end foreach side
	my $Project = new openprint::Project( $project_index );
	foreach my $version ( 1 .. $$new_specs{'versions'} ) {
		push @v, "version-$version-description";
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, "version-$version-quantity$qty_index";
		} # end foreach qty_index
	} # end foreach version
	return @v;
} # end sub variables

sub no_outputs {
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k if ! sets::isin( 'output', $variables{$k} );
	} # end foreach;
	return @v;
}

sub get_unspecified_pages {
	my ( $Project, $service_index, $printing_specs, $specs, $qty_index ) = @_;

	my $specified_pages = 0;
	foreach my $ssid ( $Project->signatures( {'Group'=>$$specs{'Group'}} ) ) {
		next if $service_index and ( $ssid >= $service_index );
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ssid );
		$specified_pages += $$sig_specs{"PageQuantity$qty_index"};
	} # end foreach

	$openprint::log->debug("Unspec: Qty$qty_index G$$specs{'Group'} GPQ:$$specs{'GroupPageQuantity'} - S$specified_pages = U" . ($$specs{'GroupPageQuantity'} - $specified_pages) );
	return $$specs{'GroupPageQuantity'} - $specified_pages;
} # end sub get_unspecified_pages

sub setup_project {
	my ( $Project, $service_index, $services, $specs, $side_one_colours, $side_two_colours, $inkCoverage, $Paper ) = @_;

	my %project = (
			'ComboItems',		$$specs{'txtPressSheetComboItems'},
			'Add Grip Width',	$$specs{'GripWidth'},
			'Add Grip Height',	$$specs{'GripHeight'},
			'Add Colour Bar',	$$specs{'rdbColourBar'},
			'image_width',		$$specs{'txtWidth'},
			'image_height',		$$specs{'txtHeight'},
			'final_width',		$$specs{'txtFinalWidth'} ? $$specs{'txtFinalWidth'} : $$specs{'txtWidth'},
			'final_height',		$$specs{'txtFinalHeight'} ? $$specs{'txtFinalHeight'} : $$specs{'txtHeight'},
			'BleedLocations',	join(',', @$specs{'BleedBottom','BleedTop','BleedLeft','BleedRight'}),
			'Calliper',			$$specs{'txtSpecificStockCalliper'},
			'CropMarkSpace',	$$specs{'txtCropMarkSpace'},
			);
	$project{print_sides} = 1;
	if ( ( @$side_two_colours > 0 ) and ( @$side_one_colours > 0 ) ) {
		$project{print_sides} = 2;
	} # end if
	$project{'side_one_colours'} = $side_one_colours;	
	$project{'side_two_colours'} = $side_two_colours;	
	$project{'inkCoverage'} = $inkCoverage;
	my @filtered_colours = filter_colours( @$side_one_colours, @$side_two_colours );
	my %mixed_colours;
	my %washed_colours;

	foreach my $index ( $Project->signatures() ) {
		next if $index >= $service_index;
		my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
		next if $$sig_specs{'pages_supplied'} eq 'Y';
		foreach my $colour ( get_colours( $sig_specs, 'SideOne' ), get_colours( $sig_specs, 'SideTwo' ) ) {
			$mixed_colours{$colour} = 1;
			foreach my $qty_index ( $Project->quantity_indexes() ) {
				$washed_colours{$colour.'-'.$$sig_specs{'ddmPress'.$qty_index}.'-'.$qty_index} += 1;
			} # end foreach
		} # end foreach
	} # end for each
	$project{'mixed_colours'} = \%mixed_colours;
	$project{'washed_colours'} = \%washed_colours;
	$project{'filtered_colours'} = \@filtered_colours;

	my $s = $openprint::dbh->selectall_arrayref(q{SELECT * FROM Inks}, { Slice => {} } );
	my %special_colours = map { $_->{pmsid}, $_ } @$s;
	$project{'special_colours'} = \%special_colours;

	foreach my $service ( 'Folding','Scoring','Perforating','DieCutting','Cutting','Numbering','Proofs' ) {
		if ( $$services{$service} ) {
			$$specs{'Has'.$service} = $project{'Has'.$service} = $$services{$service}[0];
			%{$project{$service.'Specs'}} = %{openprint::service::get_specs_ref( $Project, $$services{$service}[0] )};
		} # end if	
	} # end foreach

	if ( $$services{'Cutting'} ) {
		openprint::Estimating::Cutting::signature_calc_load_equipment( $Project );
		openprint::Estimating::Cutting::signature_calc_stock_cutting_equipment( $Project );
	} # end if

	$project{'Binding'} = openprint::print::get_book_type( $Project );
	if ( ! $$services{'NoBindery'} ) {
		$project{'NeedFolding'} = openprint::Estimating::Folding::signature_needs( $Project, $specs );
		if ( $$services{'DieCutting'} ) {
			require openprint::Estimating::DieCutting;
			$project{'NeedDieCutting'} = openprint::Estimating::DieCutting::signature_needs( $Project, $project{'DieCuttingSpecs'}, $specs );
$log->debug("Need DieCutting: $project{'NeedDieCutting'}");
			$project{'NeedScoring'} = 0;
		} else {	
			$project{'NeedScoring'} = openprint::Estimating::Scoring::signature_needs( $Project, $project{'ScoringSpecs'}, $specs, $Paper );
		} # end if
	} else {
		$project{'NeedScoring'} = 0;
		$project{'NeedFolding'} = 0;
	} # end if
	$project{'NeedUVCoating'} = openprint::Estimating::UVCoating::signature_needs( $Project, $specs );
	$project{'NeedAqueous'} = openprint::Estimating::Aqueous::signature_needs( $Project, $specs );
	@$specs{'NeedFolding','NeedScoring'} = @project{'NeedFolding','NeedScoring'};

	if ( $project{'NeedUVCoating'} ) {
		if ( ! $$services{'UVCoating'} ) {
			push @{$$services{'UVCoating'}}, openprint::print_project::insert_service( $openprint::log, $openprint::dbh, $Project->id(), 'UVCoating' );
		} # end if	
		$project{'HasUVCoating'} = $$services{'UVCoating'}[0];
	} # end if	
	if ( $project{'NeedAqueous'} ) {
		if ( ! $$services{'Aqueous'} ) {
			push @{$$services{'Aqueous'}}, openprint::print_project::insert_service( $openprint::log, $openprint::dbh, $Project->id(), 'Aqueous' );
		} # end if	
		$project{'HasAqueous'} = $$services{'Aqueous'}[0];
	} # end if	

	if ( $$services{'SaddleStitching'} ) {
		%{$project{'StitchingSpecs'}} = %{openprint::service::get_specs_ref( $Project, $$services{'SaddleStitching'}[0] )};
		$project{'HasStitching'} = $$services{'SaddleStitching'}[0];
	} elsif ( $$services{'LoopStitching'} ) {
		%{$project{'StitchingSpecs'}} = %{openprint::service::get_specs_ref( $Project, $$services{'LoopStitching'}[0] )};
		$project{'HasStitching'} = $$services{'LoopStitching'}[0];
	} # end if

	%{$project{'SpinePasteSpecs'}} = %{openprint::service::get_specs_ref( $Project, $$services{'SpinePaste'}[0] )} if $$services{'SpinePaste'};
	if ( $$services{'PerfectBound'} ) {
		$project{'HasPerfectBound'} = $$services{'PerfectBound'}[0];
		%{$project{'PerfectBoundSpecs'}} = %{openprint::service::get_specs_ref( $Project, $$services{'PerfectBound'}[0] )};
		$project{'PerfectBindCoverGutter'} = $config{'PerfectBindCoverGutter'} if $$specs{'Group'} == 1;
	} # end if

	%{$project{'UVCoatingSpecs'}} = %{openprint::service::get_specs_ref( $Project, $$services{'UVCoating'}[0] )} if $$services{'UVCoating'};
	%{$project{'AqueousSpecs'}} = %{openprint::service::get_specs_ref( $Project, $$services{'Aqueous'}[0] )} if $$services{'Aqueous'};
	return \%project;
} # end sub setup_project

sub get_colours {
	my ( $specs, $side, $v, $signature ) = @_;
	my @colours;

	$v = \%variables if ( ! $v );
	$signature = '' if ! defined $signature;

	foreach my $colour ( 'Cyan','Magenta','Yellow','Black' ) {
		if ( $$specs{'chk'.$colour.$side.$signature} ) {
			push @colours, "$colour Spot Colour";
		} # end if
	} # end foreach

	if ( $$specs{'chkProcessColour'.$side.$signature} ) {
		push @colours, 'Cyan','Magenta','Yellow','Black';
	} # end if

	foreach my $k ( keys %$specs ) {
		if ( my ( $index ) = $k =~ /^chkColourCoating(\d+)$side$signature/ ) {
			next if ! $$specs{"chkColourCoating$index$side$signature"};
			my $type = $$specs{"ColourCoatingType$index$side$signature"};
			next if ! $type;
			next if $$specs{'ColourCoatingColour'.$index.$side.$signature} eq 'None';
			#$openprint::log->debug("Found Colour $index.$side $signature $type");
			if ( $type =~ /PMS/ ) {
				if ( ! $$specs{'ColourCoatingColour'.$index.$side.$signature} ) {
					$$specs{'ColourCoatingColour'.$index.$side.$signature} = "PMS $index";
					$$v{'ColourCoatingColour'.$index.$side.$signature} = [ sets::union( 'output', @{$$v{'ColourCoatingColour'.$index.$side.$signature}} ) ];
				} #end if
				push @colours, $$specs{'ColourCoatingColour'.$index.$side.$signature};
			} else {
# Non-PMS doesn't enter the Colour NAME
				$$specs{'ColourCoatingColour'.$index.$side.$signature} = '';
				$$v{'ColourCoatingColour'.$index.$side.$signature} = [ sets::union( 'output', @{$$v{'ColourCoatingColour'.$index.$side.$signature}} ) ];
				push @colours, $type;
			} # end if type eq PMS
		} # end if
	} # end foreach
	return @colours;
} # end sub get_colours

sub get_inkcoverage {
	my ( $specs, $v, $signature ) = @_;
	$v = \%variables if ! $v;

	my %inkCoverage;
	foreach my $side ( 'SideOne','SideTwo' ) {
		foreach my $colour ( 'Cyan','Magenta','Yellow','Black' ) {
			if ( $$specs{'chk'.$colour.$side.$signature} ) {
				$$specs{$colour.'Spot'.$side.'Coverage'.$signature} =~ s/[^\d\.]//g;
				if ( ! $$specs{$colour.'Spot'.$side.'Coverage'.$signature} ) {
					$$specs{$colour.'Spot'.$side.'Coverage'.$signature} = $openprint::config{'DefaultInkCoverage'};
					$$specs{$colour.'Spot'.$side.'Coverage'.$signature} =~ s/[^\d\.]//g;
					$$v{$colour.'Spot'.$side.'Coverage'.$signature} = [ sets::union( 'output', @{$$v{$colour.'Spot'.$side.'Coverage'.$signature}} ) ];
				} else {
					$$v{$colour.'Spot'.$side.'Coverage'.$signature} = [ sets::exclude( ['output'], $$v{$colour.'Spot'.$side.'Coverage'.$signature} ) ];
				} # end if
				$inkCoverage{$colour.' Spot Colour'} += $$specs{$colour.'Spot'.$side.'Coverage'.$signature};
			} # end if
		} # end foreach
		if ( $$specs{'chkProcessColour'.$side.$signature} ) {
			foreach my $colour ( 'Cyan','Magenta','Yellow','Black' ) {
				my $key = $colour.$side.'Coverage'.$signature;
				my $c = $$specs{$key};
				$c =~ s/[^\d\.]//g;
				if ( ! $c ) {
					$c = $openprint::config{'DefaultInkCoverage'};
					$c =~ s/[^\d\.]//g;
				} # end if
				if ( $c ne $$specs{$key} ) {
					$$v{$key} = [ sets::union( 'output', @{$$v{$key}} ) ];
					$$specs{$key} = $c;
				} # end if
				$inkCoverage{$colour} += $$specs{$key};
			} # end foreach
		} # end if

		foreach my $k ( keys %$specs ) {
# checked on
			if ( my ( $index ) = $k =~ /^chkColourCoating(\d+)$side$signature/ ) {
				next if ! $$specs{"chkColourCoating$index$side$signature"};
				my $type = $$specs{"ColourCoatingType$index$side$signature"};
				if ( $type =~ /Overall/ ) {
# Nothing cuz coverage is 100%
					$$specs{'ColourCoatingCoverage'.$index.$side.$signature} = 100;
				} elsif ( ! int($$specs{'ColourCoatingCoverage'.$index.$side.$signature}) ) {
					$$specs{'ColourCoatingCoverage'.$index.$side.$signature} = $openprint::config{'DefaultInkCoverage'};
					$$v{'ColourCoatingCoverage'.$index.$side.$signature} = [ sets::union( 'output', @{$$v{'ColourCoatingCoverage'.$index.$side.$signature}} ) ];
				} # end if
				$$specs{'ColourCoatingCoverage'.$index.$side.$signature} =~ s/[^\d\.]//g;
				if ( $type =~ /PMS/ ) {
					$inkCoverage{$$specs{'ColourCoatingColour'.$index.$side.$signature}} += $$specs{'ColourCoatingCoverage'.$index.$side.$signature};
				} else {
					$inkCoverage{$type} += $$specs{'ColourCoatingCoverage'.$index.$side.$signature};
				} # end if
			} # end if
		} # end foreach k
	} # end foreach Side
	return %inkCoverage;
} # end sub get_inkcoverage

sub get_versions {
	my ( $specs, $qty_index ) = @_;
	my @versions;
	foreach my $version ( 1 .. $$specs{'versions'} ) {
		push @versions, 
			 {
				 'index' 		=> $version,
				 'description'	=> $$specs{"version-$version-description"},
				 'quantity'		=> $$specs{"version-$version-quantity$qty_index"},
			 };
	} # end foreach version
	@versions = sort { $$a{quantity} <=> $$b{quantity} } @versions;
	return @versions;
} # end sub get_versions

# Calculates, given the imposition
sub calc_from_imposition {
	my ( $Project, $service_id, $specs, $source_specs ) = @_;

	my $services = $Project->services();

	my @side_one_colours = get_colours( $specs, 'SideOne' );
	my @side_two_colours = get_colours( $specs, 'SideTwo' );
	my %inkCoverage = get_inkcoverage( $specs );

	my $project = setup_project( $Project, $service_id, $services, $specs, \@side_one_colours, \@side_two_colours, \%inkCoverage );

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		my $qty = $Project->quantity($qty_index);

		if ( ! ( $$source_specs{'Additional Impositions'.$qty_index} and @{$$source_specs{'Additional Impositions'.$qty_index}} ) ) {
			$$specs{'ddmPress'.$qty_index} = '' if $$specs{'chkOverridePress'.$qty_index} ne 'Y';
			$$specs{'PageQuantity'.$qty_index} = '' if $$specs{'chkOverridePageQuantity'.$qty_index} ne 'Y';
			$$specs{'txtImposition'.$qty_index} = '';
			$$specs{'StockType'.$qty_index} = '';
			$$specs{'StockWidth'.$qty_index} = '';
			$$specs{'StockHeight'.$qty_index} = '';
			$$specs{'txtPressSheetQty'.$qty_index} = 0;
			$$specs{'hdnNetSheetCount'.$qty_index} = 0;
			$$specs{'StockQuantity'.$qty_index} = 0;
			if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
				$$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{'ProjectMoneyFormat'}, 0 );
			} # end if
			$$specs{'txtUnitPrice'.$qty_index} = sprintf($openprint::config{'UnitPriceFormat'}, 0 );
$openprint::log->debug("no additional impos for qty $qty_index");
			next;
		} # end if
		my $Imposition = shift @{$$source_specs{'Additional Impositions'.$qty_index}};
		$$specs{'ddmRunStyle'.$qty_index} = $Imposition->runstyle();
		$$specs{'ddmPress'.$qty_index} = $Imposition->Press()->strid() if $$specs{'chkOverridePress'.$qty_index} ne 'Y';
		$$specs{'PageQuantity'.$qty_index} = $Imposition->pages() if $$specs{'chkOverridePageQuantity'.$qty_index} ne 'Y';
		$$specs{'txtImposition'.$qty_index} = $Imposition->imposition() if $$specs{'chkOverrideImposition'.$qty_index} ne 'Y';

		$$specs{'PreviousForms'.$qty_index} = 0;
		$$project{'roll2sheetcharged'} = 0;
		my %PaperCounts;
		my %PlateCounts;
		foreach my $index ( $Project->signatures() ) {
			next if ($index >= $service_id);
			my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
			$PlateCounts{$$specs{'PlateID'.$qty_index}} += $$sig_specs{'txtPlateQuantity'.$qty_index};
			$PlateCounts{'Blank'.$$specs{'PlateID'.$qty_index}} += $$sig_specs{'BlankPlateQuantity'.$qty_index};
			$$specs{'PreviousForms'.$qty_index} += 1 if compare_signatures_runstyle( $specs, $sig_specs, $qty_index );
			$$project{'roll2sheetcharged'} = 1 if $$sig_specs{'Roll2SheetCharge'.$qty_index};
		} # end foreach $index

		my $price = calc_price( $Project, $service_id, $Imposition, $project, $services, $specs, $Project->quantity($qty_index), $qty_index, \%PlateCounts );
		plate_cost( $price, \%PlateCounts, $Imposition );

		my $Paper = $Imposition->Paper();
$openprint::log->debug("Calc:From:Imposition:Paper " . $Paper->type() . ':' . $Paper->width() . 'x'.$Paper->height() );
		my $Press = $Imposition->Press();
		$$specs{'hdnBreakdown'.$qty_index} = breakdown( $price, $specs );

# Neccessary since specs do not neccessarily match the Impo
		$Imposition->save( $specs, $qty_index );
		$$specs{'ddmBleedSize'.$qty_index} = $$Imposition{'bleed_size'};
		$$specs{'ddmPress'.$qty_index} = $Press->strid();
		$$specs{'PrintingType'.$qty_index} = $Press->specification('Printing Type');
		$$specs{'txtMWeight'.$qty_index} = $Paper->mweight() ? $Paper->mweight() : $Paper->wpsi() * $Paper->width() * $Paper->height() * 1000;
		$$specs{'txtStockGSM'} = $Imposition->Paper()->gsm();
		$$specs{'txtSpecificStockCalliper'} = $Imposition->Paper()->calliper();
		if ( $Paper->type() eq 'Roll' ) {
			$$specs{'ddmStockSheetSize'.$qty_index} = $Paper->width() . '" Roll';
			$$specs{'txtPressSheetQty'.$qty_index} = sprintf('%.0f lbs', $$price{'Stock Weight'} );
			$$specs{'StockQuantity'.$qty_index} = $$price{'Stock Weight'};
$openprint::log->debug("calc_from_impos: Stock Weight: $$price{'Stock Weight'}");
		} elsif ( $Paper->type() eq 'Sheet' ) {
			$$specs{'ddmStockSheetSize'.$qty_index} = $Paper->width() . 'x' . $Paper->height();
			$$specs{'txtPressSheetQty'.$qty_index} = $$price{'Gross Sheet Count'} .'sheets';
			$$specs{'hdnNetSheetCount'.$qty_index} = $$price{'Net Sheet Count'};
			$$specs{'StockQuantity'.$qty_index} = $$price{'Gross Sheet Count'};
		} else {
			$$specs{'ddmStockSheetSize'.$qty_index} = '';
			$$specs{'txtPressSheetQty'.$qty_index} = 0;
			$$specs{'hdnNetSheetCount'.$qty_index} = 0;
			$$specs{'StockQuantity'.$qty_index} = 0;
			$$specs{'alert'} = 'Error: Unknown stock type.';
		} # end if

		$$specs{'paper_id'.$qty_index} = $Paper->id();
		$$specs{'hdnSuppliedStockWidth'.$qty_index} = $Paper->start_width();
		$$specs{'hdnSuppliedStockHeight'.$qty_index} = $Paper->start_height();
		$$specs{'StockWidth'.$qty_index} = $Paper->width();
		$$specs{'StockHeight'.$qty_index} = $Paper->height();
		$$specs{'StockType'.$qty_index} = $Paper->type();

		$$specs{'txtPlateQuantity'.$qty_index} = $$price{'txtPlateQuantity'};
		my $plate_setup = $$price{'Plate Costs'};
		$$specs{'BlankPlateQuantity'.$qty_index} = $$plate_setup{'Blank Plates'};
		$$specs{'rdbPlateType'.$qty_index} = $Press->specification('Plate Type');
		$$specs{'PlateID'.$qty_index} = $$price{'PlateID'};

		$$specs{'hdnImpressionQuantity'.$qty_index} = $$price{'Impressions'};

		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			if ( $$specs{'pages_supplied'} eq 'Y' ) {
				$$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{'ProjectMoneyFormat'}, 0 );
			} else {
				$$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{'ProjectMoneyFormat'}, $$price{'Total Cost'}*(1+$$specs{'Markup'.$qty_index}/100) );
			} # end if
		} else {
			$$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{'ProjectMoneyFormat'}, $$specs{'txtPrice'.$qty_index} );
		} # end if
		$$specs{'txtUnitPrice'.$qty_index} = sprintf($openprint::config{'UnitPriceFormat'}, $$price{'Total Cost'} / $qty );
		my $mprice = $$price{'Impression MPrice'} / $Imposition->imposition();;
		my $rate = 1+($$price{'Overs Rate'}/100);


		$$specs{'MPrice'.$qty_index} = sprintf('%.2f', $rate*(1+$$specs{'Markup'.$qty_index}/100)*($mprice + (($$price{'Ink Price'}/$qty)*1000 ) + $$price{'Paper 1000 Price'} ) );

		if ( $$specs{'txtSignatureType'} ) {
			$$specs{'PageQuantity'.$qty_index} = $Imposition->pages();
			$$specs{'txtUnspecifiedPageQuantity'.$qty_index} -= $$specs{'PageQuantity'.$qty_index};
			if ( $$specs{'txtUnspecifiedPageQuantity'.$qty_index} < 0 ) {
				$$specs{'alert'} .= 'There are more pages specified than are required.  Please correct this situation.';
			} # end if
		} # end if
	} # end foreach qty_index
} # end sub calc_from_imposition

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	# Must clear these
	%converted_imposition_cache = ();
	%filtered_imposition_cache = ();
	my $master_time = gettimeofday();
#$openprint::log->debug("Starting Printing::calc");

	if ( ! $project_index or ! $service_index ) {
		$log->debug("No Project Index ($project_index) or Service_index ($service_index)" );
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	$$specs{'Status'} = 'calculated';
	$$specs{'alert'} = '';
	$$specs{'information'} = '';

	if ( ( defined $$specs{'PageQuantity'} ) and $$specs{'PageQuantity'} =~ /[^\d\.]/ ) {
		$variables{'PageQuantity'} = [ sets::exclude( ['output'], $variables{'PageQuantity'} ) ];
		$$specs{'PageQuantity'} =~ s/[^\d\.]//g;
	} # end if

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

# First, clean up all inputs
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		my $qty = $$specs{"txtQuantity$qty_index"};
		$qty =~ s/\D//g;
		$qty = $Project->quantity( $qty_index ) if ! $qty;

		if ( $qty != $$specs{"txtQuantity$qty_index"} ) {
			$$specs{"txtQuantity$qty_index"} = $qty;
			$variables{"txtQuantity$qty_index"} = [sets::union( 'output', @{$variables{"txtQuantity$qty_index"}} ) ];
		} else {
			$variables{"txtQuantity$qty_index"} = [sets::exclude( ['output'], $variables{"txtQuantity$qty_index"} ) ];
		} # end if

		foreach my $k ( 'txtPlateChangeQuantity' ) {
			if ( $$specs{$k.$qty_index} =~ /[^\d\-]/ ) {
				$variables{$k.$qty_index} = [ sets::union( 'output', @{$variables{$k.$qty_index}} ) ];
				$$specs{$k.$qty_index} =~ s/[^\d\-]//g;
			} else {
				$variables{$k.$qty_index} = [ sets::exclude( ['output'], $variables{$k.$qty_index} ) ];
			} # end if
		} # end foreach

		if ( $$specs{'OverrideBase'.$qty_index} eq 'Y' ) {
			$variables{"OverBase$qty_index"} = [sets::exclude( ['output'], $variables{"OverBase$qty_index"} ) ];
		} else {
			$variables{'OverBase'.$qty_index} = [ sets::union( 'output', @{$variables{'OverBase'.$qty_index}} ) ];
		} # end if

		if ( $$specs{'OverrideSetup'.$qty_index} eq 'Y' ) {
			$variables{"OverSetup$qty_index"} = [sets::exclude( ['output'], $variables{"OverSetup$qty_index"} ) ];
		} else {
			$variables{'OverSetup'.$qty_index} = [ sets::union( 'output', @{$variables{'OverSetup'.$qty_index}} ) ];
		} # end if

		if ( $$specs{'OverrideRun'.$qty_index} eq 'Y' ) {
			$variables{"OverRun$qty_index"} = [sets::exclude( ['output'], $variables{"OverRun$qty_index"} ) ];
		} else {
			$variables{'OverRun'.$qty_index} = [ sets::union( 'output', @{$variables{'OverRun'.$qty_index}} ) ];
		} # end if

		# if quantity overriden then the total is total of entered quantity
		if ( ( $$specs{'OverrideBase'.$qty_index} eq 'Y' ) or ( $$specs{'OverrideSetup'.$qty_index} eq 'Y' ) or ( $$specs{'OverrideRun'.$qty_index} eq 'Y' ) ) {
	 		$$specs{'OverTotal'.$qty_index} = $$specs{'OverBase'.$qty_index} + $$specs{'OverSetup'.$qty_index} + $$specs{'OverRun'.$qty_index};
		}
	} # end foreach

	if ( ($Project->Type()->name() eq 'PresentationFolders') or (($$variable{'Group'} == 1 ) and sets::isin($$specs{'rdbTemplateType'}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) )) {
		if ( $$specs{'rdbPocketSize'} and ( $$specs{'rdbPocketSize'} ne 'Other' ) ) {
			$$specs{'PocketSize'} = $$specs{'rdbPocketSize'};	
			$variables{'PocketSize'} = [ sets::union( 'output', @{$variables{'PocketSize'}} ) ];
		} else {
			$variables{'PocketSize'} = [ sets::exclude( ['output'], $variables{'PocketSize'} ) ];
		} # end if
		if ( ! ( $$specs{'rdbPanels'} or $$specs{'txtFinalWidth'} or $$specs{'txtFinalHeight'} or $$specs{'PocketSize'} ) ) {
			return $$specs{'Status'} = 'uncalculated';
        } elsif ( ! ( $$specs{'chkPocketCenter'} or $$specs{'chkPocketLeft'} or $$specs{'chkPocketRight'} ) ) {
            $$specs{'alert'} .= 'Please select where you would like the pockets.';
            return $$specs{'Status'} = 'uncalculated';
		} # end if
	} # end if

	if ( $Project->Type()->name() eq 'Banners' ) {
		my $width = $$specs{'txtFinalWidth'};
		$width += $$specs{'PocketSize'};
		$width += $$specs{'PocketSize'};
		if ( $width != $$specs{'txtWidth'} ) {
			$$specs{'txtWidth'} = $width;
			$variables{'txtWidth'} = [ sets::union( 'output', @{$variables{'txtWidth'}} ) ];
		} else {
			$variables{'txtWidth'} = [ sets::exclude( ['output'], $variables{'txtWidth'} ) ];
		} # end if
		if ( $$specs{'txtFinalHeight'} > $$specs{'txtHeight'} ) {
			$$specs{'txtHeight'} = $$specs{'txtFinalHeight'};
			$variables{'txtHeight'} = [ sets::union( 'output', @{$variables{'txtHeight'}} ) ];
		} else {
			$variables{'txtHeight'} = [ sets::exclude( ['output'], $variables{'txtHeight'} ) ];
		} # end if
	} elsif ( $Project->Type()->name() eq 'PresentationFolders' ) {
		if ( $$specs{'ddmProjectSize'} ne 'Custom' ) {
#$log->debug("Auto calc dimensions");
# auto calc flat dimensions
			$$specs{'txtWidth'} = $$printing_specs{'txtFinalWidth'} * $$specs{'rdbPanels'};
			my $pockets;
			if ( $$specs{'rdbPanels'} == 2 ) {
				$$specs{'chkPocketCenter'} = '';
				$variables{'chkPocketCenter'} = [ sets::exclude( ['output'], $variables{'chkPocketCenter'} ) ];
			} # end if
			if ( $$specs{'chkPocketLeft'} ) {
				$$specs{'txtWidth'} += 0.75;
				$pockets += 1;
			} # end if
			if ( $$specs{'chkPocketRight'} ) {
				$$specs{'txtWidth'} += 0.75;
				$pockets += 1;
			} # end if
			if ( $$specs{'chkPocketCenter'} ) {
				$pockets += 1;
			} # end if
			$$specs{'rdbTemplateType'} = sprintf( '%dPanel%dPocket', $$specs{'rdbPanels'}, $pockets );
			$$specs{'txtHeight'} = $$printing_specs{'txtFinalHeight'} + $$specs{'PocketSize'};
			$variables{'txtWidth'} = [ sets::union( 'output', @{$variables{'txtWidth'}} ) ];
			$variables{'txtHeight'} = [ sets::union( 'output', @{$variables{'txtHeight'}} ) ];
			$openprint::log->debug("WIdth: $$specs{'txtWidth'} ");
			$openprint::log->debug("Heightth: $$specs{'txtHeight'} ");
		} else {
			$variables{'txtWidth'} = [ sets::exclude( ['output'], $variables{'txtWidth'} ) ];
			$variables{'txtHeight'} = [ sets::exclude( ['output'], $variables{'txtHeight'} ) ];
			$variables{'rdbTemplateType'} = [ sets::exclude( ['output'], $variables{'rdbTemplateType'} ) ];
		} # end if
	} # end if
	if ( $$specs{'txtSignatureType'} ) {

		if ( $$specs{'txtSignatureType'} eq 'Gate Folded Pages' ) {
			if ( $$specs{'rdbTemplateType'} eq 'SingleGateFold' ) {
				if ( $$specs{'chkOverrideDimensions'} ne 'Y' ) {
					if ( ! $$specs{'txtWidth'} ) {
						$$specs{'txtWidth'} = $$printing_specs{'txtWidth'}*1.5;
						$variables{'txtWidth'} = [ sets::union( 'output', @{$variables{'txtWidth'}} ) ];
					} else {
						$variables{'txtWidth'} = [ sets::exclude( ['output'], $variables{'txtWidth'} ) ];
					} # end if
					if ( ! $$specs{'txtHeight'} ) {
						$$specs{'txtHeight'} = $$printing_specs{'txtHeight'};
						$variables{'txtHeight'} = [ sets::union( 'output', @{$variables{'txtHeight'}} ) ];
					} else {
						$variables{'txtHeight'} = [ sets::exclude( ['output'], $variables{'txtHeight'} ) ];
					} # end if
				} # end if
				if ( ! $$specs{'txtSpreadSize'} ) {
					$$specs{'txtSpreadSize'} = 6;
					$variables{'txtSpreadSize'} = [ sets::union( 'output', @{$variables{'txtSpreadSize'}} ) ];
				} # end if
			} elsif ( $$specs{'rdbTemplateType'} eq 'DoubleGateFold' ) {
				if ( $$specs{'chkOverrideDimensions'} ne 'Y' ) {
					if ( ! $$specs{'txtWidth'} ) {
						$$specs{'txtWidth'} = $$printing_specs{'txtWidth'}*2;
						$variables{'txtWidth'} = [ sets::union( 'output', @{$variables{'txtWidth'}} ) ];
					} else {
						$variables{'txtWidth'} = [ sets::exclude( ['output'], $variables{'txtWidth'} ) ];
					} # end if
					if ( ! $$specs{'txtHeight'} ) {
						$$specs{'txtHeight'} = $$printing_specs{'txtHeight'};
						$variables{'txtHeight'} = [ sets::union( 'output', @{$variables{'txtHeight'}} ) ];
					} else {
						$variables{'txtHeight'} = [ sets::exclude( ['output'], $variables{'txtHeight'} ) ];
					} # end if
				} # end if
				if ( ! $$specs{'txtSpreadSize'} ) {
					$$specs{'txtSpreadSize'} = 8;
					$variables{'txtSpreadSize'} = [ sets::union( 'output', @{$variables{'txtSpreadSize'}} ) ];
				} # end if
			} # end if
		} elsif ( $$specs{'txtSignatureType'} eq 'Cover Pages' ) {
			$$specs{'txtSpreadSize'} = $$specs{'GroupPageQuantity'};
			$variables{'txtSpreadSize'} = [ sets::union( 'output', @{$variables{'txtSpreadSize'}} ) ];
			#$openprint::log->debug("SpreadSize: $$specs{'txtSpreadSize'}");
			if ( $$specs{'chkOverrideDimensions'} ne 'Y' ) {
				#$openprint::log->debug("TemplateType: $$specs{rdbTemplateType}");
				if ( sets::isin($$specs{'rdbTemplateType'}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
					$$specs{'txtWidth'} = $$printing_specs{'txtFinalWidth'} * $$specs{'rdbPanels'};
					my $pockets = 0;
					if ( $$specs{'rdbPanels'} == 2 ) {
						$$specs{'chkPocketCenter'} = '';
						$variables{'chkPocketCenter'} = [ sets::exclude( ['output'], $variables{'chkPocketCenter'} ) ];
					} # end if
					if ( $$specs{'chkPocketLeft'} ) {
						$$specs{'txtWidth'} += 0.75;
						$pockets += 1;
					} # end if
					if ( $$specs{'chkPocketRight'} ) {
						$$specs{'txtWidth'} += 0.75;
						$pockets += 1;
					} # end if
					if ( $$specs{'chkPocketCenter'} ) {
						$pockets += 1;
					} # end if
					$$specs{'txtHeight'} = $$printing_specs{'txtFinalHeight'} + $$specs{'PocketSize'};
				} elsif ( $$specs{'txtSpreadSize'} > 1 ) {
					$$specs{'txtWidth'} = $$printing_specs{'txtFinalWidth'}*$$specs{'GroupPageQuantity'}/2;
					$$specs{'txtHeight'} = $$printing_specs{'txtHeight'};
				} else {
					$$specs{'txtWidth'} = $$printing_specs{'txtFinalWidth'};
					$$specs{'txtHeight'} = $$printing_specs{'txtFinalHeight'};
				} # end if

				if ( $$printing_specs{'rdbTemplateType'} eq 'PerfectBound' ) {
# Perfect bound requires more width on th cover to conver the calliiper	
					my $finished_calliper = 0;
					my @Groups = sql::execute( undef, undef, 'SELECT DISTINCT strvalue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName=?', $project_index, 'Group' );
					foreach my $group_id ( @Groups ) {
# Don't include the cover
						next if $group_id == 1;
						foreach my $ss_id ( $Project->signatures({'Group'=>$group_id}) ) {
# Each group has at least 1 sig in it.
							my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );

							$finished_calliper += $$sig_specs{'GroupPageQuantity'} * $$sig_specs{'txtSpecificStockCalliper'} /2;
							last;
						} # end foreach signature in the group
					} # end foreach group

					$openprint::log->debug("Cover size calc: $finished_calliper");
					$$specs{'txtWidth'} = sprintf('%.4f', ceil(($$specs{'txtWidth'} + $finished_calliper + 2*$config{'PerfectBindGlueSpace'})*10000)/10000);
				} else {
					$$specs{'txtWidth'} = sprintf('%.3f', ceil($$specs{'txtWidth'}*1000)/1000);
				} # end if
				$variables{'txtWidth'} = [ sets::union( 'output', @{$variables{'txtWidth'}} ) ];
				$variables{'txtHeight'} = [ sets::union( 'output', @{$variables{'txtHeight'}} ) ];
			} else {
				$variables{'txtWidth'} = [ sets::exclude( ['output'], $variables{'txtWidth'} ) ];
				$variables{'txtHeight'} = [ sets::exclude( ['output'], $variables{'txtHeight'} ) ];
			} # end if
		} else {
			if ( $Project->Type()->name() eq 'ScratchPads' ) {
				$$specs{'txtSpreadSize'} = 1;
# if it's a book signature, then auto-populate the width and height
			} elsif ( $$specs{'GroupPageQuantity'} % 4 ) {
				$$specs{'txtSpreadSize'} = 2;
			} else {	
				$$specs{'txtSpreadSize'} = $$printing_specs{'txtSpreadSize'};
			} # end if
			$variables{'txtSpreadSize'} = [ sets::union( 'output', @{$variables{'txtSpreadSize'}} ) ];

			if ( $$specs{'chkOverrideDimensions'} ne 'Y' ) {
				if ( $$specs{'txtSpreadSize'} == 4 ) {
					$$specs{'txtWidth'} = $$printing_specs{'txtWidth'};
					$variables{'txtWidth'} = [ sets::union( 'output', @{$variables{'txtWidth'}} ) ];
					$$specs{'txtHeight'} = $$printing_specs{'txtHeight'};
					$variables{'txtHeight'} = [ sets::union( 'output', @{$variables{'txtHeight'}} ) ];
				} elsif ( $$specs{'txtSpreadSize'} == 2 ) {
					$$specs{'txtWidth'} = $$printing_specs{'txtFinalWidth'};
					$variables{'txtWidth'} = [ sets::union( 'output', @{$variables{'txtWidth'}} ) ];
					$$specs{'txtHeight'} = $$printing_specs{'txtFinalHeight'};
					$variables{'txtHeight'} = [ sets::union( 'output', @{$variables{'txtHeight'}} ) ];
				} else {
					$$specs{'txtWidth'} = $$printing_specs{'txtFinalWidth'};
					$variables{'txtWidth'} = [ sets::union( 'output', @{$variables{'txtWidth'}} ) ];
					$$specs{'txtHeight'} = $$printing_specs{'txtFinalHeight'};
					$variables{'txtHeight'} = [ sets::union( 'output', @{$variables{'txtHeight'}} ) ];
				} # end if
			} # end if
		} # end if Spread Type
	} else { # not a book
# If no spreadsize, then we are likely not a book, and the spread size is 2
		#$$specs{'txtSpreadSize'} = 2 if ! $$specs{'txtSpreadSize'};
		if ( $$specs{'txtFinalWidth'} and $$specs{'txtFinalHeight'} ) {
		$$specs{'txtSpreadSize'} = 2*sprintf('%.0f', $$specs{'txtWidth'}/$$specs{'txtFinalWidth'})*sprintf('%.0f', $$specs{'txtHeight'}/$$specs{'txtFinalHeight'} );
		} # end if
#$variables{'txtWidth'} = [ sets::exclude( ['output'], $variables{'txtWidth'} ) ];
#$variables{'txtHeight'} = [ sets::exclude( ['output'], $variables{'txtHeight'} ) ];
	} # end if

	if ( sets::isin( $Project->Type()->name(), [ 'Envelopes', 'NCR' ] ) ) {
		if ( $$specs{'rdbSpecificStock'} ne 'Y' ) {
			if ( $$specs{'ddmStockSheetSize'} ) {
				@$specs{'txtWidth','txtHeight'} = split('x', $$specs{'ddmStockSheetSize'} );
			} else {
				my @Papers = openprint::Paper::find( 'name'=> $$specs{'ddmStockBrand'}, 'finish'=>$$specs{'ddmStockFinish'}, 'colour'=>$$specs{'ddmStockColour'}, 'weight'=>$$specs{'ddmStockWeight'},
						'project_type_id'=>$Project->type()->id(),
						);
	$log->debug("# of papers: " . @Papers );
				my %sizes;
				foreach my $Paper ( @Papers ) {
					$sizes{(1*$$Paper{width}).'x'.(1*$$Paper{height})} = $Paper;
				} # end foreach Paper	
				my @keys = keys %sizes;
	$log->debug("# of sizes: " . @keys );
				if ( 1 == @keys ) {
					@$specs{'txtWidth','txtHeight'} = ( $sizes{$keys[0]}->width(), $sizes{$keys[0]}->height() );	
				} # end if
			} # end if
		} else {
			@$specs{'txtWidth','txtHeight'} = @$specs{'txtSpecificStockWidth','txtSpecificStockHeight'};
		} # end if
		@$specs{'txtFinalWidth','txtFinalHeight'} = @$specs{'txtWidth','txtHeight'};
		$variables{'txtWidth'} = [ sets::union( 'output', @{$variables{'txtWidth'}} ) ];
		$variables{'txtHeight'} = [ sets::union( 'output', @{$variables{'txtHeight'}} ) ];
		$variables{'txtFinalWidth'} = [ sets::union( 'output', @{$variables{'txtFinalWidth'}} ) ];
		$variables{'txtFinalHeight'} = [ sets::union( 'output', @{$variables{'txtFinalHeight'}} ) ];
	} # end if

	if ( ! ( $$specs{'txtWidth'} and $$specs{'txtHeight'} ) ) {
		$$specs{'alert'} .= 'Please enter Width and Height<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	if ( $$specs{'txtFinalWidth'} and ( $$specs{'txtWidth'} < $$specs{'txtFinalWidth'} ) ) {
		$$specs{'alert'} .= 'Flat Width must be greater than Final Width.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} elsif ( $$specs{'txtFinalHeight'} and ( $$specs{'txtHeight'} < $$specs{'txtFinalHeight'} ) ) {
		$$specs{'alert'} .= 'Flat Height must be greater than Final Height.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	if ( $Project->Type()->name() eq 'PressSheetCombination' ) {
		@$specs{'txtFinalWidth','txtFinalHeight'} = @$specs{'txtWidth','txtHeight'};
	} # end if

	my @side_one_colours = get_colours( $specs, 'SideOne' );
	my @side_two_colours = get_colours( $specs, 'SideTwo' );
	my %inkCoverage = get_inkcoverage( $specs );
	if ( ! ( $$services{'NoPrinting'} or @side_one_colours or @side_two_colours ) ) {
		$$specs{'alert'} .= 'Please choose the colours to be printed.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my @Papers;
	if ( $$specs{'rdbSpecificStock'} eq 'Y' ) {
		if ( ! $$specs{'txtSpecificStockCalliper'} ) {
			$$specs{'alert'} .= 'Please enter the stock calliper';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
		if ( ! $$specs{'CustomStockPrice'} ) {
			$$specs{'alert'} .= 'Please enter the stock cost in order to achieve an accurate imposition.';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
		if ( ( ! $$specs{'StockGrade'} ) and $$specs{'txtSpecificStockFinish'} ) {
			if ( $$specs{'txtSpecificStockFinish'} =~ /gloss/i ) {
				$$specs{'StockGrade'} = 1;
			} elsif ( $$specs{'txtSpecificStockFinish'} =~ /matte/i ) {
				$$specs{'StockGrade'} = 2;
			} elsif ( $$specs{'txtSpecificStockFinish'} =~ /offset/i ) {
				$$specs{'StockGrade'} = 4;
			} else {
				$$specs{'StockGrade'} = 3;
			} # end if
			$variables{'StockGrade'} = [ sets::union( 'output', @{$variables{'StockGrade'}} ) ];
		} else {
			$variables{'StockGrade'} = [ sets::exclude( ['output'], $variables{'StockGrade'} ) ];
		} # end if
		if ( ! $$specs{'StockGrade'} ) {
			$$specs{'alert'} .= 'Please select the grade of stock';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
		$$specs{'StockType'} =~ s/^\s*(\w*)\s*$/$1/;
		if ( ! $$specs{'StockType'} ) {
			$$specs{'alert'} .= 'Please select the stock format';
			return $$specs{'Status'} = 'uncalculated';
		} elsif ( $$specs{'StockType'} eq 'Roll' ) {
			if ( ! $$specs{'txtStockGSM'} ) {
				$$specs{'alert'} .= 'Please enter the stock gsm';
				return $$specs{'Status'} = 'uncalculated';
			} # end if

		} elsif ( $$specs{'StockType'} eq 'Sheet' ) {
			if ( ! ( $$specs{'txtCustomMWeight'} or $$specs{'txtStockGSM'} ) ) {
				$$specs{'alert'} .= 'Please enter the stock mweight or gsm';
				return $$specs{'Status'} = 'uncalculated';
			} # end if
			if ( ! $$specs{'txtSpecificStockWidth'} ) {
				$$specs{'alert'} .= 'Please enter the width of the stock';
				return $$specs{'Status'} = 'uncalculated';
			} # end if
			if ( ! $$specs{'txtSpecificStockHeight'} ) {
				$$specs{'alert'} .= 'Please enter the height of the stock';
				return $$specs{'Status'} = 'uncalculated';
			} # end if
		} # end if
		if ( $$specs{'perfecting'} eq '' ) {
			$$specs{'perfecting'} = sets::isin( $$specs{'StockGrade'},[4,5] ) ? 'Y' : 'N';
		} # end if
		my $Paper = openprint::Paper::load_from_signature( $Project, $specs );
$openprint::log->debug( $Paper->to_string() );
		push @Papers, $Paper;
		foreach my $k ( 'txtSpecificStockCalliper', 'txtSpecificStockWidth','txtSpecificStockHeight','txtCustomMWeight','txtCustomStockPrice', 'txtStockGSM','basis_mweight', 'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight' ) {
			$variables{$k} = [ sets::exclude( ['output'], $variables{$k} ) ];
		} # end foreach
		if ( ( ! $$specs{'txtCustomMWeight'} and $Paper->gsm() ) ) {
			$variables{'txtCustomMWeight'} = [ sets::union( 'output', @{$variables{'txtCustomMWeight'}} ) ];
			$$specs{'txtCustomMWeight'} = $Paper->mweight();
		} # end if
		if ( ( ! $$specs{'basis_mweight'} and $Paper->gsm() ) ) {
			$variables{'basis_mweight'} = [ sets::union( 'output', @{$variables{'basis_mweight'}} ) ];
			$$specs{'basis_mweight'} = $Paper->basis_mweight();
		} # end if
		if ( ! $$specs{'txtStockGSM'} ) {
			$variables{'txtStockGSM'} = [ sets::union( 'output', @{$variables{'txtStockGSM'}} ) ];
			$$specs{'txtStockGSM'} = $Paper->gsm();
		} # end if
	} else {
		$variables{'txtStockGSM'} = [ sets::union( 'output', @{$variables{'txtStockGSM'}} ) ];
		if ( ! $$specs{'ddmStockBrand'} ) {
			$$specs{'alert'} .= 'Please select a stock.';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
		if ( ! $$specs{'ddmStockFinish'} ) {
			$$specs{'alert'} .= 'Please select a stock finish.';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
		if ( ! $$specs{'ddmStockColour'} ) {
			$$specs{'alert'} .= 'Please select a stock colour.';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
		if ( ! $$specs{'ddmStockWeight'} ) {
			$$specs{'alert'} .= 'Please select a stock weight.';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
		@Papers = openprint::Paper::find( 'name'=> $$specs{'ddmStockBrand'}, 'finish'=>$$specs{'ddmStockFinish'}, 'colour'=>$$specs{'ddmStockColour'}, 'weight'=>$$specs{'ddmStockWeight'},
				'project_type_id'=>$Project->Type()->id(),
				);
# Load this here, so that later cloning will copy the prices as well.
		foreach my $P ( @Papers ) {
			$P->prices();
		} # end foreach
		if ( ! @Papers ) {
			$openprint::log->warn('no papers');
			$$specs{'alert'} .= 'Unable to find any stocks matching your specifications.<br/>';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
		@$specs{'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight','StockGrade'} = $Papers[0]->get('name','finish','colour','weight','grade');
		$$specs{'txtSpecificStockCalliper'} = $Papers[0]->calliper() if @Papers;
		foreach my $k ( 'txtSpecificStockCalliper', 'txtSpecificStockWidth','txtSpecificStockHeight','txtCustomMWeight','txtCustomStockPrice', 'txtStockGSM','txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight','StockGrade' ) {
			$variables{$k} = [ sets::union( 'output', @{$variables{$k}} ) ];
		} # end foreach
	} # end if
	if ( ! @Papers ) {
		$$specs{'alert'} .= 'There was a problem loading the specified paper.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

foreach my $P ( @Papers ) {
$openprint::log->debug("Initial Papers: " . $P->type() .':' . $P->width() . 'x' . $P->height() );
} # end foreach
# If Stock size is overridden, check the list of stocks to see if the specified on is in the list.  If it isn't, then add duplicates, cut to size

	if (
			( $$specs{'chkOverrideSheetSize1'} eq 'Y' ) or
			( $$specs{'chkOverrideSheetSize2'} eq 'Y' ) or
			( $$specs{'chkOverrideSheetSize3'} eq 'Y' )
	   ) {
		my @Ps;
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			if ( ! ( $$specs{'OverrideStockWidth'.$qty_index} or $$specs{'OverrideStockHeight'.$qty_index} ) ) {
				@$specs{'OverrideStockWidth'.$qty_index, 'OverrideStockHeight'.$qty_index} = split 'x', $$specs{'ddmStockSheetSize'.$qty_index};
			} # end if
			my $found = 0;

			foreach my $P ( @Papers ) {
#$openprint::log->debug("Paper " . $P->width() .'x'.$P->height() . ' ' . "$$specs{'OverrideStockWidth'.$qty_index }x$$specs{'OverrideStockHeight'.$qty_index}" );
				if ( $P->width() == $$specs{'OverrideStockWidth'.$qty_index} and $P->height() == $$specs{'OverrideStockHeight'.$qty_index} ) {
#$openprint::log->debug('gound it'); 
					$found = 1;
					# Don't need to add it, because it's already in @Papers
					#push @Ps, $P;
				} # end if
			} # end foreach

			if ( ! $found ) {
				# Find ones that are an even cut
				foreach my $P ( @Papers ) {
					next if ! $P->cuttable();
					if ( $P->type() eq 'Roll' ) {
						next if $$specs{'OverrideStockHeight'.$qty_index};
						next if $P->start_width();
					} elsif ( $P->type() eq 'Sheet' ) {
# Don't cut sheets into rolls
						next if ! $$specs{'OverrideStockHeight'.$qty_index};

						if ( 
								( ($P->start_width() % $$specs{'OverrideStockWidth'.$qty_index}) and ($P->start_height() % $$specs{'OverrideStockHeight'.$qty_index} ) ) and
								( ($P->start_width() % $$specs{'OverrideStockHeight'.$qty_index}) and ($P->start_height() % $$specs{'OverrideStockWidth'.$qty_index} ) ) )  {
							next;
						} # en dif
					} # end if
					$found = 1;
					my $P2 = $P->clone();
# Make sure gsm has calculated
					$P2->gsm();
					$P2->width( $$specs{'OverrideStockWidth'.$qty_index} );
					$P2->height( $$specs{'OverrideStockHeight'.$qty_index} );
					if ( $P2->type() ne 'Roll' ) {
						$P2->mweight( 0 );
					} else {
						$P2->start_width( $$specs{'OverrideStockWidth'.$qty_index} );
					} # end if
					push @Ps, $P2;
				} # end foreach paper
			} # end if found

			if ( ! $found ) {
				foreach my $P ( @Papers ) {
# Don't cut rolls into sheets
					next if ! $P->cuttable();
					if ( $P->type() eq 'Roll' ) {
						next;
					} elsif ( $P->type() eq 'Sheet' ) {
# Don't cut sheets into rolls
						next if ! $$specs{'OverrideStockHeight'.$qty_index};
# Must be big enough to cut
						next if ( $P->start_width() < $$specs{'OverrideStockWidth'.$qty_index} or $P->start_height() < $$specs{'OverrideStockHeight'.$qty_index} ) and ( $P->start_width() < $$specs{'OverrideStockHeight'.$qty_index} or $P->start_height() < $$specs{'OverrideStockWidth'.$qty_index} );
					} # end if
					my $P2 = $P->clone();

# Make sure gsm has calculated
					$P2->gsm();
					$P2->width( $$specs{'OverrideStockWidth'.$qty_index} );
					$P2->height( $$specs{'OverrideStockHeight'.$qty_index} );
					if ( $P2->type() ne 'Roll' ) {
						$P2->mweight( 0 );
					} else {
						$P2->start_width( $$specs{'OverrideStockWidth'.$qty_index} );
					} # end if
					push @Ps, $P2;
				} # end foreach paper
			} # end if found
		} # end foreach qty_index
		push @Papers, @Ps;
	} # end if override

	if ( ! @Papers ) {
		$$specs{'alert'} .= 'There was a problem loading the specified paper.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	@Papers = map { $_->clone() } @Papers;

	foreach my $P ( @Papers ) {
		$openprint::log->debug("Paper: " . $P->to_string() . ' Minimum: ' . $P->minimum_order() ) if ( $debug or 1 );
		$Papers{$P->to_string()} = $P;
	} # end foreach

	my $project = setup_project( $Project, $service_index, $services, $specs, \@side_one_colours, \@side_two_colours, \%inkCoverage, $Papers[0] );

	if ( $$services{'NoPrinting'} ) {
		foreach my $k ('txtImposition','ddmRunStyle','hdnImpositionColumns','hdnImpositionRows','hdnImpositionDutchColumns','hdnImpositionDutchRows','StockWidth','StockHeight' ) {
			foreach my $qty_index ( $Project->quantity_indexes() ) {
				$$specs{"$k$qty_index"} = $$specs{$k};
			} # end foreach
		} # end foreach K
		return $$specs{'Status'} = 'calculated';
	} # end if

	my %presses = select_presses( $Project, $Papers[0], $specs, \@side_one_colours, \@side_two_colours );
	my @possible_presses;
	foreach my $press_id ( keys %presses ) {
		if ( ! $presses{$press_id} ) {
			push @possible_presses, new openprint::Equipment($press_id);
		} # end if
	} # end foreach
	if ( ! @possible_presses ) {
		$$specs{'alert'} = 'There were no possible presses. Your project may be too large for us.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} elsif ( $debug ) {
		$openprint::log->debug( "Presses: " . join(',', map { $_->strid() } @possible_presses ) );
	} # end if
	@possible_presses = sort { $a->strid() <=>$b->strid() } @possible_presses;

	my @available_printingtypes;
	foreach my $Press ( @possible_presses ) {
		push @available_printingtypes, $Press->specification('Printing Type');
	} # end foreach
	@available_printingtypes = sets::union( @available_printingtypes );

#$openprint::log->debug("Master time before qty: " . ( sprintf('%.4f', tv_interval( [$master_time])*1000) ) .' usecs' );
	my %threads;
	my %prices;

	my @quantity_indexes = $Project->quantity_indexes();
	if ( ! @quantity_indexes ) {
$log->warn("There are no quantities!");
	} # end if

	foreach my $qty_index ( reverse @quantity_indexes ) {
		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = 0;
		} else {
			$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		} # end if
		my $qty = $$specs{"txtQuantity$qty_index"};
		$qty = $Project->quantity($qty_index) if $qty eq '';
		if ( ! $qty ) {
			$log->error("There must be a qty here!");
			next;
		} else {
$log->debug("QTY: $qty");
		} # end if

		$$specs{'hdnBreakdown'.$qty_index} = "QTY: $qty: ";
		$qty *= $$specs{'PageQuantity'} if $$specs{'PageQuantity'};
		$qty *= $$specs{'txtNameQuantity'} if $$specs{'txtNameQuantity'};
$log->debug("Page QTY $$specs{'PageQuantity'} ($$specs{'txtNameQuantity'}) $qty");

		$$specs{'totalSpreads'} = 1;
# Figure out how many spreads we need!
		if ( $$specs{'txtSignatureType'} ) {
			$$specs{'totalSpreads'} = $$specs{'GroupPageQuantity'};
			$$specs{'txtUnspecifiedPageQuantity'.$qty_index} = get_unspecified_pages( $Project, $service_index, $printing_specs, $specs, $qty_index );
			$$specs{'txtUnspecifiedPageQuantity'.$qty_index} = 0 if $$specs{'txtUnspecifiedPageQuantity'.$qty_index} < 0;
		} # end if

		delete $$specs{'PreviousStockType'};
		delete $$specs{'PreviousGrainDirection'};
		foreach my $index ( $Project->signatures({'Group'=>$$specs{'Group'}}) ) {
			next if $index >= $service_index;
			my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
			$$specs{'PreviousStockType'} = $$sig_specs{'StockType'.$qty_index};
			$$specs{'PreviousGrainDirection'} = $$sig_specs{'rdbGrainDirection'.$qty_index};
			last;
		} # end foreach

		delete $$specs{'PrintingTypes'};
#$openprint::log->debug('available: ' . join(',', @available_printingtypes) );
		if ( $$printing_specs{'PrintingType'} and sets::isin( $$printing_specs{'PrintingType'}, \@available_printingtypes ) ) {
			$$specs{'PrintingTypes'} = [ $$printing_specs{'PrintingType'} ];
#$openprint::log->debug("PT: " . join(',', @{$$specs{'PrintingTypes'}} ) );
		} else {

			if ( $$specs{'txtSignatureType'} eq 'Cover Pages' ) {
# FIgure out printing types
				foreach my $index ( $Project->signatures({'type'=>'Interior Pages'}) ) {
					my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
					if ( sets::isin( $$sig_specs{'PrintingType'.$qty_index}, \@available_printingtypes ) ) {
						if ( $$sig_specs{'PrintingType'.$qty_index} eq 'Digital' ) {
							$$specs{'PrintingTypes'} = ['Digital'];
						} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Waterless' ) {
							$$specs{'PrintingTypes'} = [ 'Waterless', 'Offset' ];
						} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Offset' ) {
							$$specs{'PrintingTypes'} = ['Offset','Waterless'];
						} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Sheetfed' ) {
							$$specs{'PrintingTypes'} = ['Sheetfed','Web'];
						} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Web' ) {
							$$specs{'PrintingTypes'} = ['Sheetfed','Web'];
						} else {
							$openprint::log->warn("Unknown printing type: " . $$sig_specs{'PrintingType'.$qty_index} );
						} # end if
					} # end if
					last if $$specs{'PrintingTypes'};
				} # end foreach

			} elsif ( $$specs{'txtSignatureType'} eq 'Interior Pages' ) {
# if the cover is digital, then we need digital
# if another interior spread is digital, then we need digital
# if the cover is offset, then we need offset
# if the cover is waterless, then we can do waterless, or offset
				foreach my $index ( $Project->signatures({'type'=>'Interior Pages'}) ) {
					next if $index == $service_index;
					my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
					next if ( ( $index > $service_index ) and ( $$sig_specs{'OverridePrintingType'.$qty_index} ne 'Y' ) );

					if ( sets::isin( $$sig_specs{'PrintingType'.$qty_index}, \@available_printingtypes ) ) {
						if ( $$sig_specs{'PrintingType'.$qty_index} eq 'Digital' ) {
							$$specs{'PrintingTypes'} = ['Digital'];
						} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Waterless' ) {
							$$specs{'PrintingTypes'} = [ 'Waterless', 'Offset' ];
						} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Offset' ) {
							$$specs{'PrintingTypes'} = ['Offset'];
						} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Web' ) {
							$$specs{'PrintingTypes'} = ['Web'];
						} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Sheetfed' ) {
							$$specs{'PrintingTypes'} = ['Sheetfed'];
						} # end if
					} # end if
					last if $$specs{'PrintingTypes'};
				} # end foreach

				if ( ( ! $$specs{'PrintingTypes'} ) and ( $$specs{'OverridePrintingType'.$qty_index} ne 'Y' ) ) {
					my $cover_specs;
					foreach my $index ( $Project->signatures({'type'=>'Cover Pages'}) ) {
						$cover_specs = openprint::service::get_specs_ref( $Project, $index );
						last;
					} # end foreach
					if ( $cover_specs ) {
						if ( sets::isin( $$cover_specs{'PrintingType'.$qty_index}, \@available_printingtypes ) ) {
							if ( $$cover_specs{'PrintingType'.$qty_index} eq 'Digital' ) {
								$$specs{'PrintingTypes'} = ['Digital'];
							} elsif ( $$cover_specs{'PrintingType'.$qty_index} eq 'Waterless' ) {
								$$specs{'PrintingTypes'} = [ 'Waterless', 'Offset' ];
							} elsif ( $$cover_specs{'PrintingType'.$qty_index} eq 'Offset' ) {
								$$specs{'PrintingTypes'} = ['Offset'];
							} elsif ( $$cover_specs{'PrintingType'.$qty_index} eq 'Web' ) {
								$$specs{'PrintingTypes'} = ['Sheetfed','Web'];
							} elsif ( $$cover_specs{'PrintingType'.$qty_index} eq 'Sheetfed' ) {
								$$specs{'PrintingTypes'} = ['Sheetfed','Web'];
							} # end if
						} # end if
					} # end if
				} # end if PrintingTypes
			} # end if Spread Type
		} # end if printing_specs{'PrintingType'}
		if ( $debug ) {
			if ( $$specs{'PrintingTypes'} ) {
				$openprint::log->debug("Printing TYpes for qty$qty_index " . join(',', @{$$specs{'PrintingTypes'}} ) );
			} else {
				$openprint::log->debug("No printing types");
			} # end if
		} # end if

		my %PaperCounts;
		my %PlateCounts;
		foreach my $index ( $Project->signatures() ) {
# Get plates in each previous signature, so we can get qty discounts
			next if $service_index and ($index >= $service_index);
			my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
			next if $$sig_specs{'pages_supplied'} eq 'Y';
			$PlateCounts{$$specs{'PlateID'.$qty_index}} += $$sig_specs{'txtPlateQuantity'.$qty_index};
			$PlateCounts{'Blank'.$$specs{'PlateID'.$qty_index}} += $$sig_specs{'BlankPlateQuantity'.$qty_index};
		} # end foreach $index

		$$project{print_sides} = 1;
		if ( ( @side_two_colours > 0 ) and ( @side_one_colours > 0 ) ) {
			$$project{print_sides} = 2;
		} # end if

		my $imposition_count = 0;

		if ( $$specs{'chkOverridePress'.$qty_index} eq 'Y' ) {
			$variables{'ddmPress'.$qty_index} = [ sets::exclude( ['output'], $variables{'ddmPress'.$qty_index} ) ];
			if ( ! $$specs{'ddmPress'.$qty_index} ) {
#$openprint::log->error("No overriden press!");
				$$specs{'alert'} .= 'Please specify the desired press.<br/>';
				return $$specs{'Status'} = 'uncalculated';
			} # end if

			my $OverridePress = openprint::Equipment::find_one('strid'=>$$specs{'ddmPress'.$qty_index});
			if (! $OverridePress ) {
				$$specs{'alert'} = 'Cant find the press that you have chosen.';
				return $$specs{'Status'} = 'uncalculated';
			} # end if

			if ( $presses{$OverridePress->id()} ) {
				$$specs{'alert'} = 'The press that you have chosen is not appropriate for the following reason: ' .$presses{$OverridePress->id()};
				return $$specs{'Status'} = 'uncalculated';
			} # end if
		} else {
			$variables{'ddmPress'.$qty_index} = [ sets::union( 'output', @{$variables{'ddmPress'.$qty_index}} ) ];
		} # end if

		if ( $$specs{'chkOverrideRunStyle'.$qty_index} eq 'Y' ) {
			$variables{'ddmRunStyle'.$qty_index} = [ sets::exclude( ['output'], $variables{'ddmRunStyle'.$qty_index} ) ];
		} else {
			$variables{'ddmRunStyle'.$qty_index} = [ sets::union( 'output', @{$variables{'ddmRunStyle'.$qty_index}} ) ];
		} # end if
#$openprint::log->debug("SignatureType: $$specs{'txtSignatureType'} Group: $$specs{'Group'} " . $$specs{'txtUnspecifiedPageQuantity'.$qty_index});
		if ( $Project->Type()->name() eq 'ScratchPads' ) {
			delete $$project{'SpreadLayout'};

			# I do not understand this, but I assume it has something to do with separate backer
			$qty *= $$specs{'txtUnspecifiedPageQuantity'.$qty_index} if $$specs{'txtUnspecifiedPageQuantity'.$qty_index};
			$$specs{'txtUnspecifiedPageQuantity'.$qty_index} = 1;
		} elsif ( $$specs{'txtSignatureType'} ) {
			if ( $$specs{'chkOverridePageQuantity'.$qty_index} eq 'Y' ) {
				$$project{'SpreadLayout'} = $$specs{'PageQuantity'.$qty_index} / $$specs{'txtSpreadSize'};
			} else {
				$$project{'SpreadLayout'} = $$specs{'txtUnspecifiedPageQuantity'.$qty_index} / $$specs{'txtSpreadSize'};
			} # end if
		} else {
			$openprint::log->debug("No spread layout for you!");
		} # end if

		if ( (exists $$project{'SpreadLayout'}) and ! $$project{'SpreadLayout'} ) {
			$$specs{"txtImposition$qty_index"} = '';
			$$specs{"ddmRunStyle$qty_index"} = '';
			$$specs{"PageQuantity$qty_index"} = 0;
			$$specs{'information'} .= "No more pages need to be specified for quantity $qty_index.";
			$prices{$qty_index} = {};
			next;
		} # end if

# add all the impositions for each press
		foreach my $Press ( @possible_presses ) {
			$impositions{$Press->id()} = undef;
			$openprint::log->debug("Trying press " . $Press->strid()) if $debug;
			if ( $$specs{'OverridePrintingType'.$qty_index} eq 'Y' ) {
				if ( $Press->specification('Printing Type') ne $$specs{'PrintingType'.$qty_index} ) {
					$openprint::log->warn("QTY $qty_index Press $$Press{strid} Printing Type (" . $Press->specification('Printing Type') .") is not the overriden type " . $$specs{'PrintingType'.$qty_index} ) if $debug or 1;
					next;
				} else {
					$openprint::log->warn("QTY $qty_index Press $$Press{strid} Printing Type (" . $Press->specification('Printing Type') .") IS the overriden type " . $$specs{'PrintingType'.$qty_index} ) if $debug or 1;
				} # end if
				$variables{'PrintingType'.$qty_index} = [ sets::exclude( ['output'], $variables{'PrintingType'.$qty_index} ) ];
			} else {
				$variables{'PrintingType'.$qty_index} = [ sets::union( 'output', @{$variables{'PrintingType'.$qty_index}} ) ];
				if ( $$specs{'PrintingTypes'} and ! sets::isin( $Press->specification('Printing Type'), $$specs{'PrintingTypes'} ) ) {
					if ( $$specs{'chkOverridePress'.$qty_index} eq 'Y' and $$specs{'ddmPress'.$qty_index} eq $Press->strid() ) {
						$$specs{'alert'} .= 'Press ' . $Press->strid() . ' Printing Type ('.$Press->specification('Printing Type') . ') is not in PrintingTypes  '. join(',', @{$$specs{'PrintingTypes'}} ) . '<br/>';
					} # end if
					next;
				} # end if
			} # end if
# If we have a plate type override, then make sure that this press can do it.
			if ( ( $$specs{'chkOverridePlateType'.$qty_index} eq 'Y' ) and ( $Press->specifcation('Plate Type') ne $$specs{'rdbPlateType'.$qty_index} ) ) {
				$openprint::log->warn("Press Plate Type ");
				next;
			} # end if
			if ( (! $$services{'Folding'} ) and ($Press->specification('Sheeter') ne 'Y' ) ) {
				$openprint::log->error("No Sheeter");
				next;
			} # end if

# This perfecting stuff: default to on, turn off if press can't do it, or the job is single sided.
			my $do_perfecting = 1;
			if ( ! sets::isin('Perfecting', split(',',$Press->specification('Runstyles') ) ) ) {
$openprint::log->debug("** This Press Can't Perfect - Missing \'Perfecting Press\' = Y equipment spec ***") if $debug;
				$do_perfecting = 0;
			} elsif ( @side_one_colours > int($Press->specification('Number of Colours')/2) or @side_two_colours > int($Press->specification('Number of Colours')/2) ) {
$openprint::log->debug("** This to many colours to  Perfect  ***") if $debug;
				$do_perfecting = 0;
			} elsif ( $$project{print_sides} == 1 ) {
				$do_perfecting = 0;
$openprint::log->debug("** One sided:  Perfect  ***") if $debug;
			} elsif ( ( $_ = $Press->specification('Maximum Calliper Perfecting') ) and ( $$specs{'txtSpecificStockCalliper'} > $_ ) ) {
				$do_perfecting = 0;
$openprint::log->debug("** Too thick to:  Perfect  ***") if $debug;
			} # end if
			my $do_work_turn = $$project{print_sides} == 2 ? 1 : 0;
			if ( $do_work_turn ) {
				# Coatings like AQ and Varnish are done in a separate pass.  So we don't count them in this check
				my @Coatings = map { $_->name() } openprint::Service::find('category'=>'Coating');
				if ( ! $Papers[0]->doublesided() ) {
$openprint::log->debug("No W&T due to doublesided" . $Papers[0]->name() );
					$do_work_turn = 0;
				} elsif ( sets::exclude( \@Coatings, $$project{'filtered_colours'} ) > $Press->specification('Number of Colours') and $Press->specification('Multipass', $Papers[0]->gsm() ) ne 'Y' ) {
$openprint::log->debug("No W&T due to multipass" . $Papers[0]->gsm() );
					$do_work_turn = 0;
				} elsif ( $$specs{'sides_the_same'} eq 'Y' ) {
					$do_work_turn = 0;
				} # end if
			} # end if

# not all of the presses have a gutter spec so we will continue to use Grip for Width and Height
			if ( ! sets::isin( $Project->Type()->name(), [ 'Envelopes', 'NCR' ] ) ) {
				$$project{'Grip'} = $Press->specification('Grip');
				$$project{'Gutter'} = $Press->specification('Gutter');
				if ( $$specs{'chkOverrideBleedSize'.$qty_index} eq 'Y' ) {
					$$project{'BleedSize'} = 1*$$specs{'ddmBleedSize'.$qty_index};
					$variables{'ddmBleedSize'.$qty_index} = [ sets::exclude( ['output'], $variables{'ddmBleedSize'.$qty_index} ) ];
				} else {
					$$project{'BleedSize'} = 1*$Press->specification('Default Bleed Size'.$Project->Type()->name() );
					$$project{'BleedSize'} = 1*$Press->specification('Default Bleed Size' ) if ! $$project{'BleedSize'};
					$variables{'ddmBleedSize'.$qty_index} = [ sets::union( 'output', @{$variables{'ddmBleedSize'.$qty_index}} ) ];
				} # end if

				# PMS
				my @c = sets::exclude( ['Cyan','Magenta','Yellow','Black','Cyan Spot Colour','Magenta Spot Colour','Black Spot Colour','Yellow Spot Colour','Varnish Gloss Overall','Varnish Matte Overall','Varnish Gloss Spot','Varnish Matte Spot','Aqueous Gloss Spot','Aqueous Gloss Overall'], [ @side_one_colours, @side_two_colours ] );

				if ( ! $$specs{'rdbColourBar'} ) {
					if ( @c ) {
						$$project{'Add Colour Bar'} = $Press->specification('Colour Bar Default');
					} else {
						$$project{'Add Colour Bar'} = $Press->specification('Process Colour Bar Default');
					} # end if
				} # end if
				if ( $$project{'Add Colour Bar'} eq 'Y' ) {
					if ( @c ) {
						$$project{'colour_bar_size'} = $Press->specification('Colour Bar Size');
					} else {
						$$project{'colour_bar_size'} = $Press->specification('Process Colour Bar Size');
						if ( !$$project{'colour_bar_size'} ) {
							$$project{'colour_bar_size'} = $Press->specification('Colour Bar Size');
						}
					} # end if
				} else {
					$$project{'colour_bar_size'} = 0;
				} # end if
				$$project{'Colour Bar Orientation'} = $Press->specification('Colour Bar Orientation');
				$$project{'Perfecting Single Gutter Size'} = $Press->specification('Perfecting Single Gutter Size');
				$$project{'Perfecting Double Gutter Size'} = $Press->specification('Perfecting Double Gutter Size');
			} else {
				$$project{'colour_bar_size'} = 0;
			} # end if Envelopes
			$$project{'Orientation'} = $Press->specification('Orientation');
			$$project{'Maximum Image Area Length'} = $Press->specification('Maximum Image Area Length');
			$$project{'Maximum Image Area Width'} = $Press->specification('Maximum Image Area Width');
			$$project{'Runstyles'} = $Press->specification('Runstyles');
			$$project{'txtSpreadSize'} = $$specs{'txtSpreadSize'};

			my @impositions;
			my %imps;

			foreach my $Paper ( @Papers ) {
				#Paper might have different callipers
				$$project{'Calliper'} = $Paper->calliper();
				if ( ( $$specs{'OverrideStockType'.$qty_index} eq 'Y' ) and ( $Paper->type() ne $$specs{'StockType'.$qty_index} ) ) {
					next;
				} # end if
				if ( $$specs{'PreviousStockType'} and ( $Paper->type() ne $$specs{'PreviousStockType'} ) ) {
					$openprint::log->debug("Not consider paper cuz it's not the previous stock type " . $Paper->type() .' ' .$$specs{'PreviousStockType'} ) if $debug;
					next;
				} # end if
				my @imps;
				if ( $Paper->type() eq 'Roll' ) {
					next if ! sets::isin( 'Roll', split(',', $Press->specification('Feed') ) );
					next if $Paper->width() > $Press->specification('Maximum Sheet Width');
					next if $Press->specification('Maximum Roll Width') and ( $Paper->width() > $Press->specification('Maximum Roll Width') );
#$openprint::log->debug('blah'.$Paper->to_string());

					my $P = $Paper->clone();
					my @i;
					my @cut_offs;
					if ( my $co = $Press->specification('Cut Off') ) {
						@cut_offs = reverse sort split( ',', $co );
					} elsif ( my $min = $Press->specification('Cut Off Minimum') ) {
						my $increment = $Press->specification('Cut Off Increment');
						my $cut_off = $Press->specification('Cut Off Maximum');
						while ( $cut_off >= $min ) {
							push @cut_offs, $cut_off;
							# Neccessary due to floating point arithmetic errors
							$cut_off = sprintf('%.5f', $cut_off - $increment );
						} # end while cutoff > min
					} # end if

					if ( @cut_offs ) {
# We start with the largest, which is the first.
# We get our impositions.  Then we cut them, fitting them into the cut offs.
						$$project{'Cut Off'} = $cut_offs[0];
						my @start_impositions = openprint::imposition::get_imposition( $project, $do_work_turn, $do_perfecting, $$specs{'Versions'}, $P,
									undef, 
									undef, $Press,
									);
						foreach my $I ( @start_impositions ) {
							#find minimum cut off
							my $used_height = $I->used_height();
							my $new_height = 0;
							my @my_cut_offs = @cut_offs;
							while ( @my_cut_offs ) {
								last if $my_cut_offs[0] < $used_height;
								$new_height = shift @my_cut_offs; 
							} # end foreach cut off
							next if ! $new_height;
							$I->Paper()->height( $new_height );
							push @i, $I->copy();
#$I->display('starting');
							while ( $I->rows() > 1 ) {
								# Don't cut them down because they just become the sheetwork version
								last if $I->runstyle() eq 'Work & Tumble';
								$I->rows( $I->rows() - 1 );
								my $used_height = $I->used_height();
								my $new_height = 0;
								while ( @my_cut_offs ) {
									last if $my_cut_offs[0] < $used_height;
									$new_height = shift @my_cut_offs; 
								} # end foreach cut off
								last if ! $new_height;
								$I->Paper()->height( $new_height );
								push @i, $I->copy();
#$I->display('after cutdown');
							} # end while
						} # end foreach $I
					} else {
						push @i, openprint::imposition::get_imposition( $project, $do_work_turn, $do_perfecting, $$specs{'Versions'}, $P,
								undef, 
								undef, $Press,
								);
					} # end if
					if ( $P->start_width() ) {
						push @imps, @i;
					} else {
						foreach my $i ( @i ) {
							my $i2 = $i->copy();
							$i2->Paper()->width( $i2->used_width() ) if ! $i2->Paper()->width();
							$Papers{$i2->Paper()->to_string()} = $i2->Paper()->clone() if ! $Papers{$i2->Paper()->to_string()};
							while ( $i2->columns() ) {
								push @imps, $i2;
								$i2 = $i2->copy();
								$i2->columns( $i2->columns()-1 );
								$i2->Paper()->width( $i2->used_width() );
								$Papers{$i2->Paper()->to_string()} = $i2->Paper()->clone() if ! $Papers{$i2->Paper()->to_string()};
								openprint::imposition::check_setup( $i2, $project );
								$i2->columns(0) if $Press->specification('Minimum Sheet Width') and ($i2->paper()->width() < $Press->specification('Minimum Sheet Width'));
								$i2->columns(0) if $Press->specification('Minimum Roll Width') and ($i2->paper()->width() < $Press->specification('Minimum Roll Width'));
							} # end while
						} # end foreach
					} # end if start_width or cut for all sizes
				} else { # Sheet Fed
					next if ! sets::isin( 'Sheet', split(',', $Press->specification('Feed') ) );

					next if ! ( $Paper->width() and $Paper->height() );
					next if ( $Press->specification('Printing Type') eq 'Digital' and ! $Paper->digital() );

					my $P = $Paper->clone();

# Cut to fit on press
					if ( 
							( $P->width() > $Press->specification('Maximum Sheet Width') or $P->height() > $Press->specification('Maximum Sheet Length') )
							and
							( $P->width() > $Press->specification('Maximum Sheet Length') or $P->height() > $Press->specification('Maximum Sheet Width') )
					   ) {
						next if ! $P->cuttable();
						while (
								( $P->width() > $Press->specification('Maximum Sheet Width') or $P->height() > $Press->specification('Maximum Sheet Length') )
								and
								( $P->width() > $Press->specification('Maximum Sheet Length') or $P->height() > $Press->specification('Maximum Sheet Width') )
							  ) {
							last if ! ( 
									( $P->width() > $$specs{'txtWidth'} and $P->height() > $$specs{'txtHeight'} ) or ( $P->height() > $$specs{'txtHeight'} and $P->width() > $$specs{'txtWidth'} ) );
							$P->cut();
							$Papers{$P->to_string()} = $P->clone() if ! $Papers{$P->to_string()};
						} # end while
					} # end if

# Keep cutting while the sheet still fits on the press.  I originally thought that we shouldn't do this, because why would you want to run a half sheet if a full sheet fits?  The answer: small jobs, that due to overs requires the same sheets whether you run full or half.  So by running half, you need half the # of real sheets.
					while (
							( $P->width() >= $Press->specification('Minimum Sheet Width') and $P->height() >= $Press->specification('Minimum Sheet Length') )
							or
							( $P->width() >= $Press->specification('Minimum Sheet Length') and $P->height() >= $Press->specification('Minimum Sheet Width') )
						  ) {

						if ( ! ( 
									( $P->width() >= $$specs{'txtWidth'} and $P->height() >= $$specs{'txtHeight'} ) 
									or ( $P->height() >= $$specs{'txtWidth'} and $P->width() >= $$specs{'txtHeight'} ) 
							   ) ) {
							#$openprint::log->debug("Next paper because it's too small for the item" . $P->width() . 'x' . $P->height() . ' => ' . $$specs{'txtWidth'} . 'x' . $$specs{'txtHeight'} ) if $debug;
							last;
						} # end if

						my @i = openprint::imposition::get_imposition( $project, $do_work_turn, $do_perfecting, $$specs{'Versions'}, $P,
								undef, 
								undef,
								$Press );
						last if ! @i;
						push @imps, @i;

						last if ( ! $P->cuttable() );
						$P = $P->clone();
						$P->cut();
						$Papers{$P->to_string()} = $P->clone() if ! $Papers{$P->to_string()};
					} # end while cutting it
				} # end if Web or Sheet

if ( $debug ) {
$openprint::log->debug("Sorting from paper " . $Paper->to_string() . ' on ' . $Press->strid() );	
foreach my $i ( @imps ) {
$i->display();
}
}
	if ( $debug ) {
		foreach my $P ( @Papers ) {
			$openprint::log->debug("Paper: " . $P->to_string() );
		} # end foreach
	} # end if
				foreach my $imp ( @imps ) {
					if ( $imp->imposition() > $qty ) {
						$openprint::log->debug("Next because $$imp{imposition} > $qty");
					} # end if
					my $add = 1;
					my $str = sprintf('%dx%d+%dx%d-%s-%s', @$imp{'columns','rows','dutch_columns','dutch_rows','runstyle','image_orientation'} );
					if ( ($$specs{'chkOverrideSheetSize'.$qty_index} eq 'Y') and ( $imp->Paper()->type() eq 'Sheet' )
							and ( $imp->Paper()->width() == $$specs{"OverrideStockWidth$qty_index"} ) 
							and ( $imp->Paper()->height() == $$specs{"OverrideStockHeight$qty_index"} )
					   ) {
					} elsif ( ($$specs{'chkOverrideSheetSize'.$qty_index} eq 'Y') and ( $imp->Paper()->type() eq 'Roll' )
							and ( $imp->Paper()->width() == $$specs{"OverrideStockWidth$qty_index"} ) 
					   ) {
					} elsif ( ( $$specs{'OverrideCutOff'.$qty_index} eq 'Y' ) and ( $imp->Paper()->height() == $$specs{"CutOff$qty_index"} ) ) {
						#$add = 1;
					} elsif ( ! $imps{$str} ) {
						#$add = 1;
					} else {
						for ( my $j = 0; $j < @{$imps{$str}}; $j += 1 ) {
							my $I = $imps{$str}[$j];

							if ( ($$specs{'chkOverrideSheetSize'.$qty_index} eq 'Y') and ( $I->Paper()->width() == $$specs{"OverrideStockWidth$qty_index"}) and ( $I->Paper()->height() == $$specs{"OverrideStockHeight$qty_index"} )) {
								last;
							} elsif ( ( $$specs{'OverrideCutOff'.$qty_index} eq 'Y' ) and ( $I->Paper()->height() == $$specs{"CutOff$qty_index"} ) ) {
								last;
							} # end if

							my %BiggerPrice = $I->Paper()->get_price($qty/$I->imposition());
							my %SmallerPrice = $imp->Paper()->get_price($qty/$imp->imposition());
							if (
									( $I->Paper()->area() >= $imp->Paper()->area() )
									and
									( $I->Paper()->minimum_order() >= $imp->Paper()->minimum_order() )
									and
									( (1*$BiggerPrice{'100lb'}) >= (1*$SmallerPrice{'100lb'}) )
									and
									( ! ( ! $I->Paper()->is_cut() and $imp->Paper()->is_cut() ) )
							   ) {
								splice @{$imps{$str}}, $j, 1;
								$j -= 1;
							} elsif (
									( $I->Paper()->area() < $imp->Paper()->area() )
									and
									( $I->Paper()->minimum_order() <= $imp->Paper()->minimum_order() )
									and
									( (1*$BiggerPrice{'100lb'}) <= (1*$SmallerPrice{'100lb'}) )
									and
									( ( ! $I->Paper()->is_cut() ) or ( $imp->Paper()->is_cut() ) )
									) {
								# Already have a much better sheet
								$add = 0;
							} # end if
						} # end for
					} # end if overriden or not or cached
					push @{$imps{$str}}, $imp if $add;
				} # end foreach imp

			} # end foreach Paper

			push @impositions, map {@{$_}} values %imps;

#$openprint::log->debug("After filtering qty: $qty_index, Press: $$Press{strid} " . ( sprintf('%.4f', tv_interval( [$master_time])*1000) ) .' usecs' );
			if ( $debug or 0 ) {
				$openprint::log->warn('Impositions after filtering for '. $Press->strid() . ': ' . @impositions );
				foreach my $I ( @impositions ) {
					$I->display();
				} # end foreach
			} # end if
			if ( ! @impositions ) {
#$openprint::log->debug("No impositions for press " . $Press->strid()) if $debug;
				if ( ( $$specs{'chkOverridePress'.$qty_index} eq 'Y' ) and ( $Press->strid() eq $$specs{'ddmPress'.$qty_index} ) ) {
					$$specs{'alert'} .= 'There were no possible impositions.  Your project may be too large for us.<br/>';
					return $$specs{'Status'} = 'uncalculated';
				} # end if
			} # end if

			$imposition_count += scalar @impositions;
			$impositions{$Press->id()} = \@impositions;
		} # end foreach Press
# FIXME this used to generate the old impo, and add it, but what we really need to do is search through the impos we have, and select the old one, moving it to the front.  This is made more complex for book because they have not been converted here.
		@{$impositions{''}} = ();
		if ( $$specs{'ddmPress'.$qty_index} and ($$specs{'chkOverridePress'.$qty_index} ne 'Y') ) {
			if ( sets::isin( $$specs{'ddmPress'.$qty_index}, map { $_->strid() } @possible_presses ) ) {
			if ( ( my @Equipment = openprint::Equipment::find( 'strid'=>$$specs{'ddmPress'.$qty_index} ) ) ) {
				my $E = $Equipment[0];
				if ( $impositions{$E->id()} ) {

					for ( my $i = 0; $i < @{$impositions{$E->id()}}; $i += 1 ) {
						my $I = $impositions{$E->id()}[$i];
						if ( 
								( $I->imposition() != $$specs{'txtImposition'.$qty_index} ) and
								( $I->runstyle() eq $$specs{'ddmRunStyle'.$qty_index} ) and
								( $I->Paper()->width() == $$specs{'StockWidth'.$qty_index} ) and 
								( $I->Paper()->height() == $$specs{'StockHeight'.$qty_index} ) 
						   ) {
							push @{$impositions{''}}, splice @{$impositions{$E->id()}}, $i, 1;
							$i -= 1;
						} # end if
					} # end foreach Imposition
				} # end if
			} # end if we have equipment
			} # end if we have equipment
		} # end if can preload

		if ( ! $imposition_count ) {
			$$specs{'alert'} .= 'There were no possible impositions for your specifications.<br/>';
			return $$specs{'Status'} = 'uncalculated';
		} # end if

		$$project{'roll2sheetcharged'} = 0;
		my %previous_forms_cache;
		foreach my $index ( $Project->signatures() ) {
			next if $service_index and ($index >= $service_index);
			my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
			next if $$sig_specs{'pages_supplied'} eq 'Y';
			$$project{'roll2sheetcharged'} = 1 if $$sig_specs{'Roll2SheetCharge'.$qty_index};
			my $hash_key = join(',', @$sig_specs{'ddmPress'.$qty_index,'ddmRunStyle'.$qty_index,'PageQuantity'.$qty_index,'txtImposition'.$qty_index} );
			$previous_forms_cache{$hash_key} += 1;
		} # end foreach $index

		# These are passed along for consideration in get_project_price.  Hence they should only occur after the current service, right?
		my @signatures;
		foreach ( sort $Project->signatures({'Group'=>$$specs{'Group'}}) ) {
			push @signatures, $_ if $_ > $service_index;
		} # end foreach

		%signature_price_cache = ();
		my @versions = get_versions( $specs, $qty_index );
# Only thread qtys 2 and 3
		if ( $threading and ($qty_index > 1) ) {
			$threads{$qty_index} = threads->create( sub { 
					$openprint::dbh = sql::open_sql( $openprint::log, 
						'database'	=> $openprint::r->dir_config('db_name'),
						'driver'	=> $openprint::r->dir_config('db_driver'), 
						'host'		=> $openprint::r->dir_config('db_host'),
						'login'		=> $openprint::r->dir_config('db_user'),
						'password'	=> $openprint::r->dir_config('db_password'),
						);
					return get_project_price( $Project, $service_index, $project, $specs, $specs, $qty, $qty_index, \@possible_presses, $printing_specs, \@versions, \%PlateCounts, \%PaperCounts, \%previous_forms_cache, \@signatures, undef, 1 );
					} );
		} else {
			my $sig_price = get_project_price( $Project, $service_index, $project, $specs, $specs, $qty, $qty_index, \@possible_presses, $printing_specs, \@versions, \%PlateCounts, \%PaperCounts, \%previous_forms_cache, \@signatures, undef, 1 );
			$prices{$qty_index} = $sig_price;
		} # end if

	} # end foreach quantity

	foreach my $qty_index ( reverse @quantity_indexes ) {
		my $qty = $Project->quantity($qty_index);
		next if ! defined $qty;
		next if ! int $qty;

		$$specs{'hdnBreakdown'.$qty_index} = "QTY: $qty: ";
		$qty *= $$specs{'PageQuantity'} if $$specs{'PageQuantity'};
		$qty *= $$specs{'txtNameQuantity'} if $$specs{'txtNameQuantity'};
		if ( $threading and ($qty_index > 1) ) {
# The thread may not be defined if for example no more spreads needed to be calculated
			if ( defined $threads{$qty_index} ) {
				$prices{$qty_index} = $threads{$qty_index}->join();
			} # end if
		} # end if
		my $b_price = $prices{$qty_index};

		if ( ! $b_price ) {
			$$specs{'alert'} .= "Unable to calculate a price for printing for qty $qty_index.<br/>";
			$$specs{'Status'} = 'uncalculated';
			next;
		} # end if

		my %best_price = %{$b_price};
		my $Imposition = $$b_price{'Imposition'};
		next if ! $Imposition;
		my $Paper = $Imposition->Paper();
		my $Press = $Imposition->Press();

		$$specs{'hdnBreakdown'.$qty_index} = breakdown( $b_price, $specs );
#$Imposition->display();
#$openprint::log->debug( breakdown( $b_price, $specs ) );

		$Imposition->save( $specs, $qty_index );
		$$specs{'Additional Impositions'.$qty_index} = $$b_price{'Impositions'};
		# Pop off the first one
		shift @{$$specs{'Additional Impositions'.$qty_index}};

		$$specs{'ddmBleedSize'.$qty_index} = $$Imposition{'bleed_size'};
		$$specs{'ddmPress'.$qty_index} = $Press->strid();
		$$specs{'PrintingType'.$qty_index} = $Press->specification('Printing Type');
		$$specs{'txtMWeight'.$qty_index} = $Paper->mweight() ? $Paper->mweight() : $Paper->wpsi() * $Paper->width() * $Paper->height() * 1000;
		$$specs{'txtStockGSM'} = $Imposition->Paper()->gsm();
		$$specs{'txtSpecificStockCalliper'} = $Imposition->Paper()->calliper();
		if ( $Paper->type() eq 'Roll' ) {
			$$specs{'ddmStockSheetSize'.$qty_index} = $Paper->width() . '" Roll';
			$$specs{'txtPressSheetQty'.$qty_index} = $best_price{'Stock Weight'}.'lbs';
			$$specs{'minimum_stock_size'.$qty_index} = $Imposition->used_width().'&quot;';
			$$specs{'StockQuantity'.$qty_index} = $best_price{'Stock Weight'};
		} elsif ( $Paper->type() eq 'Sheet' ) {
			$$specs{'ddmStockSheetSize'.$qty_index} = $Paper->width() . 'x' . $Paper->height();
			$$specs{'txtPressSheetQty'.$qty_index} = $best_price{'Gross Sheet Count'} .'sheets';
			$$specs{'hdnNetSheetCount'.$qty_index} = $best_price{'Net Sheet Count'};
			$$specs{'StockQuantity'.$qty_index} = $best_price{'Gross Sheet Count'};
			$$specs{'minimum_stock_size'.$qty_index} = sprintf('%s&quot; x %s&quot;', $Imposition->used_width(), $Imposition->used_height() );
		} else {
			$$specs{'ddmStockSheetSize'.$qty_index} = '';
			$$specs{'txtPressSheetQty'.$qty_index} = 0;
			$$specs{'hdnNetSheetCount'.$qty_index} = 0;
			$$specs{'StockQuantity'.$qty_index} = 0;
			$$specs{'alert'} = 'Error: Unknown stock type.';
		} # end if
#$$specs{'hdnPaperPrice'.$qty_index} = $best_price{'Paper Price'};
		$$specs{'hdnSuppliedStockWidth'.$qty_index} = $Paper->start_width();
		$$specs{'hdnSuppliedStockHeight'.$qty_index} = $Paper->start_height();
		$$specs{'StockWidth'.$qty_index} = $Paper->width();
		$$specs{'StockHeight'.$qty_index} = $Paper->height();
		$$specs{'StockType'.$qty_index} = $Paper->type();

		$$specs{'txtPlateQuantity'.$qty_index} = $best_price{'txtPlateQuantity'};
		my $plate_setup = $best_price{'Plate Costs'};
		$$specs{'BlankPlateQuantity'.$qty_index} = $$plate_setup{'Blank Plates'};
		$$specs{'rdbPlateType'.$qty_index} = $Press->specification('Plate Type');
		$$specs{'PlateID'.$qty_index} = $best_price{'PlateID'};
#
		$$specs{'PerPlateCost'.$qty_index} = $best_price{'Plate Cost'};
		$$specs{'PlateTotalCost'.$qty_index} = $best_price{'Plate Price'};
		$$specs{'PlateMakeReady'.$qty_index} = $best_price{'Plate Total'};

 		my $TPress = $Imposition->Press();
 		my %TPrice = openprint::service::get_price_object( 'PlateMakeReady', undef, $TPress );
		
		$$specs{'PerPlateMkRd'.$qty_index} = $TPrice{'Price'};

		$$specs{'RunChargeTotal'.$qty_index} = $best_price{'Run Total'};
		$$specs{'PressWashPrice'.$qty_index} = $best_price{'Press Wash Price'};
		$$specs{'PressWashCharge'.$qty_index} = $best_price{'Press Wash Total'};
		$$specs{'PressWashes'.$qty_index} = $best_price{'Press Washes'};
	
		my $stock_qt = $best_price{'Stock Quantity'};

 		$$specs{'OverBase'.$qty_index} = $$stock_qt{'Net Sheet Count'};
 		$$specs{'OverSetup'.$qty_index} = $$stock_qt{'Setup Overs'};
 		$$specs{'OverRun'.$qty_index} = $$stock_qt{'Run Overs'};
	 	$$specs{'OverTotal'.$qty_index} = $$stock_qt{'Total Overs'};
		$$specs{'ImpositionCharge'.$qty_index} = $best_price{'Imposition Total'};
		#delete $$specs{'Impositions'};
		#delete $$specs{'Additional Impositions'.$qty_index};
		my $PageCharge = $best_price{'Page Charge'};
		$$specs{'PageCharge'.$qty_index} = $$PageCharge{'Total'};
		my $SteppingCharge = $best_price{'Stepping Charge'};
		$$specs{'SteppingCharge'.$qty_index} = $$SteppingCharge{'Total'};
		$$specs{'InkTotalCharge'.$qty_index} = $best_price{'Ink Price'};
		$$specs{'InkMixCharge'.$qty_index} = $best_price{'Ink Mix Charge'};

		$$specs{'Roll2SheetCharge'.$qty_index} = $best_price{'Roll2SheetCharge'};
#
	
#	$openprint::log->debug("Testingtext here : Run Charge = $best_price{'Run Total'}");
#	$openprint::log->debug("Testingtext here : Minimum Run Charge = $best_price{'Minimum Run Charge'}");


		$$specs{'hdnImpressionQuantity'.$qty_index} = $best_price{'Impressions'};
#$$specs{'RunTime'.$qty_index} = $best_price{'RunTime'};

		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			if ( $$specs{'pages_supplied'} eq 'Y' ) {
				$$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{'ProjectMoneyFormat'}, 0 );
			} else {
				$$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{'ProjectMoneyFormat'}, $best_price{'Total Cost'}*(1+$$specs{'Markup'.$qty_index}/100) );
			} # end if
		} else {
			$$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{'ProjectMoneyFormat'}, $$specs{'txtPrice'.$qty_index} );
		} # end if
		$$specs{'txtUnitPrice'.$qty_index} = sprintf($openprint::config{'UnitPriceFormat'}, $best_price{'Total Cost'} / $qty );
		my $mprice = $best_price{'Impression MPrice'} / $Imposition->imposition();
		my $rate = 1+($best_price{'Overs Rate'}/100);
		my $ink = (($best_price{'Ink Price'}/$qty)*1000 );
		$$specs{'MPrice'.$qty_index} = sprintf('%.2f', $rate*(1+$$specs{'Markup'.$qty_index}/100)*($mprice + $ink + ($best_price{'Paper 1000 Price'}*$rate) ) );
#$openprint::log->debug("MPrice: Rate: $rate Impression: $best_price{'Impression MPrice'}/$$Imposition{imposition}=$mprice, Ink: (($best_price{'Ink Price'}/$qty)*1000 )=$ink, PaperM: $best_price{'Paper 1000 Price'}");

		if ( $$specs{'txtSignatureType'} ) {
			if ( $$specs{'chkOverridePageQuantity'.$qty_index} eq 'Y' ) {
				$variables{'PageQuantity'.$qty_index} = [ sets::exclude( ['output'], $variables{'PageQuantity'.$qty_index} ) ];
			} else {
				$variables{'PageQuantity'.$qty_index} = [ sets::union( 'output', @{$variables{'PageQuantity'.$qty_index}} ) ];
				$$specs{'PageQuantity'.$qty_index} = $Imposition->pages();
			} # end if
			$$specs{'txtUnspecifiedPageQuantity'.$qty_index} -= $$specs{'PageQuantity'.$qty_index};
			if ( $$specs{'txtUnspecifiedPageQuantity'.$qty_index} < 0 ) {
				$$specs{'alert'} .= "There are more pages specified than are required.  Please correct this situation.";
			} # end if
		} # end if
		$$specs{'PaperMessage'.$qty_index} = $Paper->message();
		$$specs{'NeedCutting'} = openprint::Estimating::Cutting::signature_needs( $Project, $specs );
#$openprint::log->debug("Master time after qty: $qty_index" . ( sprintf('%.4f', tv_interval( [$master_time])*1000) ) .' usecs' );
	} # end foreach quantity

	return $$specs{'Status'};
} # end sub calc

sub breakdown {
	my ( $price, $specs ) = @_;

	if ( ! $$price{'Imposition'} ) {
		$openprint::log->debug(" Price $price $$price{Imposition}");
	} # end if

	my $Imposition = $$price{'Imposition'};
	my $Paper = $Imposition->Paper();
	my $Press = $Imposition->Press();
	my $stock_qty = $$price{'Stock Quantity'};

	my $breakdown = '';
	$breakdown .= sprintf('Colour Bar %s %s, Bleed: %s<br/>', $Imposition->colour_bar_size(), $Imposition->colour_bar_orientation(), $$Imposition{'bleed_size'} );
	$breakdown .= '<b>Setups</b><br/>';
	$breakdown .= $$price{'Setup Breakdown'};
	$breakdown .= sprintf('Roll2Sheet Charge: $%1$.2f<br/>', $$price{'Roll2SheetCharge'} ) if $$price{'Roll2SheetCharge'};
	my $ImpositionCharge = $$price{'Imposition Price'};
	if ( $$ImpositionCharge{units} eq 'Per Page' ) {
		$breakdown .= sprintf('Imposition Charge: $%1$.2f + $%3$.2f*%4$d pages = $%2$.2f<br/>', @$price{'Imposition MakeReady','Imposition Total'}, $$ImpositionCharge{Price}, $Imposition->pages() );
	} elsif ( $$ImpositionCharge{units} eq 'Per Square Inch of Object' ) {
		$breakdown .= sprintf('Imposition Charge: $%1$.2f + $%3$.2f*%4$s x %5$s = $%2$.2f<br/>', @$price{'Imposition MakeReady','Imposition Total'}, $$ImpositionCharge{Price}, $Imposition->object_width(), $Imposition->object_height() );
	} elsif ( $$ImpositionCharge{units} eq 'Per Square Inch of Layout' ) {
		$breakdown .= sprintf('Imposition Charge: $%1$.2f + $%3$.2f*%4$s x %5$s = $%2$.2f<br/>', @$price{'Imposition MakeReady','Imposition Total'}, $$ImpositionCharge{Price}, $Imposition->layout_width(), $Imposition->layout_height() );
	} else {
		$breakdown .= sprintf('Imposition Charge: $%1$.2f + $%3$.2f*%4$d out = $%2$.2f<br/>', @$price{'Imposition MakeReady','Imposition Total'}, $$ImpositionCharge{Price}, $Imposition->imposition() );
	} # end if

	if ( my $PageCharge = $$price{'Page Charge'} ) {
		$breakdown .= sprintf('Page Charge: $%1$.2f%2$s * %4$d pages = $%3$.2f<br/>', @$PageCharge{'Price','units','Total'}, $Imposition->pages() );
	} # end if
	if ( my $SteppingCharge = $$price{'Stepping Charge'} ) {
		$breakdown .= sprintf('Stepping Charge: $%1$.2f%2$s * %4$dout  = $%3$.2f<br/>', @$SteppingCharge{'Price','units','Total'}, $Imposition->imposition() );
	} # end if

	$breakdown .= sprintf("\tRunstyle Charge:\t\$%.2f<br/>", $$price{'Runstyle Charge'} );
	$breakdown .= sprintf("\tWork & Turn Dry Cost:\t\$%.2f<br/>", @$price{'WorkTurn Dry Charge'} ) if $$price{'WorkTurn Dry Charge'};
	$breakdown .= sprintf("\tPMS Ink Mix Charge:\t\$%.2f<br/>", $$price{'Ink Mix Charge'} ) if $$price{'Ink Mix Charge'};
	$breakdown .= sprintf("\tPress Wash Charge:\t\$%.2f * \%d washes = \$%.2f<br/>", @$price{'Press Wash Price','Press Washes','Press Wash Total'});
	$breakdown .= sprintf('Plate Make Ready: $%.2f%s %dplates = $%.2f<br/>', @$price{'Plate Setup Price','Plate Setup Units','Plate Setup Count', 'Plate Total'} );
	$breakdown .= sprintf("\tSetup Total:\t\t\$%.2f<br/><b>Run Charges:</b><br/>", $$price{'Setup Total'} );
	if ( $Press->specification('Charge for setup overs') eq 'N' ) {
		$breakdown .= sprintf('Impression Charge: %d/%d Per Hour * $%.2f%s = $%.2f<br/>', ( $$price{'Impressions'}-$$stock_qty{'Setup Overs'} ),@$price{'Run Speed','Impression Cost','Impression Units','Impression Price'} );
	} else {
		$breakdown .= sprintf('Impression Charge: %d/%d Per Hour * $%.2f%s = $%.2f<br/>', @$price{'Impressions','Run Speed','Impression Cost','Impression Units','Impression Price'} );
	} # end if

	$breakdown .= sprintf("\tMinimum Run Charge: \$%.2f<br/>", $$price{'Minimum Run Charge'} );
	$breakdown .= sprintf("\tRun Charge Total:\t\$%.2f<br/>", $$price{'Run Total'} );
	$breakdown .= '<b>Material Charges:</b><br/>';
	my $plate_costs = $$price{'Plate Costs'};
	$breakdown .= sprintf( 'Plates: %d %s * $%.2f per plate = $%.2f<br/>', @$price{'txtPlateQuantity','PlateID','Plate Cost','Plate Price'});
	$breakdown .= sprintf( 'Blank Plates: %d plates * $%.2f per plate = $%.2f<br/>', @$plate_costs{'Blank Plates','Blank Price'}, $$plate_costs{'Blank Price'} * $$plate_costs{'Blank Plates'}) if defined $$plate_costs{'Blank Plates'};

	$breakdown .= sprintf( 'Overs: Base:%s Setup:%s Run:%s FM:%s Additional Plate:%s Bindery: %d (FoldMakeReady: %d FoldRun: %d', @$stock_qty{'Net Sheet Count','Setup Overs','Run Overs','FM Overs','Additional Plate Overs', 'BinderyOvers', 'FoldingMakeReadyOvers','FoldingRunOvers'} );
	$breakdown .= ' Cutting: ' . $$stock_qty{'CuttingOvers'} if $$stock_qty{'CuttingOvers'};
	$breakdown .= ' Scoring: ' . $$stock_qty{'ScoringOvers'} if $$stock_qty{'ScoringOvers'};
	$breakdown .= ' DieCutting: ' . $$stock_qty{'DieCuttingOvers'} if $$stock_qty{'DieCuttingOvers'};
	$breakdown .= ' UV Coating: ' . $$stock_qty{'UVOvers'} if $$stock_qty{'UVOvers'};
	$breakdown .= ') Total: ' . $$stock_qty{'Total Overs'} . '<br/>';
	$breakdown .= $$price{'Ink breakdown'};
	$breakdown .= sprintf('Ink Total: $%.2f<br/>', $$price{'Ink Price'} );
	$breakdown .= sprintf('Total: $%.2f<br/>', $$price{'Total Cost'} );
	$breakdown .= $$price{'Proofs Breakdown'};
	$breakdown .= $$price{'UVCoating Breakdown'};
	$breakdown .= $$price{'Aqueous Breakdown'};
	$breakdown .= $$price{'Cutting Breakdown'};
	$breakdown .= $$price{'Scoring Breakdown'} if $$price{'Scoring Breakdown'};
	$breakdown .= $$price{'Numbering Breakdown'} if $$price{'Numbering Breakdown'};
	$breakdown .= $$price{'DieCutting Breakdown'} if $$price{'DieCutting Breakdown'};
	$breakdown .= $$price{'Folding Breakdown'};
	$breakdown .= $$price{'Perforating Breakdown'} if $$price{'Perforating Breakdown'};
	$breakdown .= $$price{'AdditionalSignature Breakdown'};
	$breakdown .= $$price{'Stitching Breakdown'};
	$breakdown .= $$price{'SpinePaste Breakdown'};
	$breakdown .= $$price{'PerfectBound Breakdown'};
	$breakdown .= $$price{'Paper Breakdown'};
	$breakdown .= sprintf('Comparison Cost: %.2f<br/>', $$price{'Comparison Cost'}) if $$price{'Comparison Cost'} ne '';
	return $breakdown;
} # end sub breakdown

sub get_imposition_price {
} # end sub get_imposition_price
# impositions is a hash of imps for each press

sub calculate_impositions {
	my ( $Project, $Press, $sig_specs, $qty_index, $qty, $PaperCounts, $versions, $project ) = @_;

	my @impositions;
	if ( ! $Press ) {
		if ( $impositions{''} and @{$impositions{''}} ) {
#$openprint::log->debug("# of elevated impositions: " . @{$impositions{''}} );
			@impositions = @{$impositions{''}};
			$Press = $impositions[0]->Press();
		} # end if
		if ( ! $Press ) {
#$openprint::log->debug("No Press");
			return;
		} # end if
	} else {
		@impositions = @{$impositions{$Press->id()}} if $impositions{$Press->id()};
	} # end if
	if ( ! @impositions ) {
		return;
	} # end if
	if ( $debug ) {
		$openprint::log->debug("QTY: $qty_index before " . @impositions );
		foreach my $imp ( @impositions ) {
			$imp->display();
		} # end foreach
#$openprint::log->debug("SPread Layout: $SpreadLayout");
	} # end if
	my $SpreadLayout;
	my $cache_string = join('-', $$Press{id}, $SpreadLayout, @$sig_specs{'PrintingTypes', 'PreviousStockType', 'PreviousGrainDirection'} );
	if ( $Project->Type()->name() eq 'ScratchPads' ) {
		$SpreadLayout = 0;
#$qty *= $$specs{'txtUnspecifiedPageQuantity'.$qty_index};
	} elsif ( $$sig_specs{'txtSignatureType'} ) {
		$SpreadLayout = ( $$sig_specs{'chkOverridePageQuantity'.$qty_index} eq 'Y' ? $$sig_specs{'PageQuantity'.$qty_index} : $$sig_specs{'txtUnspecifiedPageQuantity'.$qty_index} ) / $$sig_specs{'txtSpreadSize'};
		$cache_string = join('-', $$Press{id}, $SpreadLayout, @$sig_specs{'PrintingTypes', 'PreviousStockType', 'PreviousGrainDirection'} );
		if ( $SpreadLayout > 0 ) {
			$openprint::log->debug("Converting Impositions spread Layout: $SpreadLayout : imps:" . @impositions) if $debug or 0;
			if ( $use_converted_imposition_cache and ( $_ = $converted_imposition_cache{$cache_string} ) ) {
				@impositions = map { $_->copy() } @{$_};
			} else {
				@impositions = @{$converted_imposition_cache{$cache_string}} = openprint::imposition::convert_impositions( $SpreadLayout, $$sig_specs{'txtSpreadSize'}, \@impositions );
			} # end if
		} # end if
	} # end if

	if ( ( $$sig_specs{'chkOverrideSheetSize'.$qty_index} eq 'Y' ) and ! $$sig_specs{"OverrideStockWidth$qty_index"} ) {
		@$sig_specs{"OverrideStockWidth$qty_index","OverrideStockHeight$qty_index"} = split('x', $$sig_specs{"ddmStockSheetSize$qty_index"} );
	}
	my @dont_do_pages = split(',', $Press->specification('DontDoPages'));
	my @results;
	if ( $use_filtered_imposition_cache and ( $_ = $filtered_imposition_cache{$cache_string} ) ) {
		@impositions = @{$_};
	} else {
		foreach my $imp ( @impositions ) {
			my $Paper = $imp->Paper();
			if ( ( $$sig_specs{'chkOverrideImposition'.$qty_index} eq 'Y' ) and ( $imp->imposition() != $$sig_specs{'txtImposition'.$qty_index} ) ) {
				$openprint::log->debug("Doesn't match imposition override " . $imp->imposition() . ' != ' . $$sig_specs{'txtImposition'.$qty_index}) if $debug;
				next;
			} # end if
			if ( ( $$sig_specs{'chkOverrideRunStyle'.$qty_index} eq 'Y' ) and ( $imp->runstyle() ne $$sig_specs{'ddmRunStyle'.$qty_index} ) ) {
				$openprint::log->debug("Doesn't match runstyle override " . $imp->runstyle() . ' != ' . $$sig_specs{'ddmRunStyle'.$qty_index}) if $debug;
				next;
			} # end if

			if ( $$sig_specs{'chkOverrideSheetSize'.$qty_index} eq 'Y' ) {
				if ( 
						( $Paper->width() != $$sig_specs{"OverrideStockWidth$qty_index"} ) or 
						( $$sig_specs{"OverrideStockHeight$qty_index"} and ( $Paper->height() != $$sig_specs{"OverrideStockHeight$qty_index"} ) )) {
#$imp->display('Not overriden sheet size! ' . $$sig_specs{"OverrideStockWidth$qty_index"} . 'x' . $$sig_specs{"OverrideStockHeight$qty_index"} );
					next;
				} else {
					$imp->display('Accepted stock! ' . $$sig_specs{"OverrideStockWidth$qty_index"} . 'x' . $$sig_specs{"OverrideStockHeight$qty_index"} );
				} # end if
			} elsif ( $$sig_specs{'OverrideCutOff'.$qty_index} eq 'Y' ) {
				if ( $Paper->height() != $$sig_specs{"CutOff$qty_index"} ) {
					next;
				} # end if
			}  # end if
			if ( $$sig_specs{'chkOverrideGrainDirection'.$qty_index} eq 'Y' ) {
#$log->debug("Grain Direction override: " . $imp->grain_direction() . " ne " . $$sig_specs{'rdbGrainDirection'.$qty_index} ) if $imp->grain_direction() ne $$sig_specs{'rdbGrainDirection'.$qty_index};
				next if $imp->grain_direction() ne $$sig_specs{'rdbGrainDirection'.$qty_index};	
			} elsif ( $$sig_specs{'PreviousGrainDirection'} and ( $imp->grain_direction() ne $$sig_specs{'PreviousGrainDirection'} ) ) {
#$imp->display("PreviousGrainDirection: $$sig_specs{'PreviousGrainDirection'} ne " . $imp->grain_direction() );
				next;
			} # end if

			if ( ( $imp->runstyle() eq 'Web' ) and $openprint::usergroup::groups_cache{'Web Estimating'} and ! openprint::usergroup::is_user_in( ['Web Estimating'], $openprint::session{'user_id'} ) ) {
				$openprint::log->debug('No Web 4 U');
				next;
			} # end if

			if ( $$sig_specs{'PreviousStockType'} and ( $Paper->type() ne $$sig_specs{'PreviousStockType'} ) ) {
#$imp->display("PreviousStockType: $$sig_specs{'PreviousStockType'} ne " . $imp->Paper()->type() );
				next;
			} # end if

			if ( $SpreadLayout > 0 ) {
				my %max_impositions;
				my $max_pages = 0;
				foreach my $imp ( @impositions ) {
					$max_pages = $imp->pages() if $imp->pages() > $max_pages;
					$max_impositions{$imp->pages()} = $imp->imposition() if $imp->imposition() > $max_impositions{$imp->pages()};
				} # end foreach
				$max_pages = ceil( $max_pages / 3 );
				if ( $debug or 0 ) {
					$openprint::log->debug("Max pages: $max_pages, ");
					foreach my $p ( keys %max_impositions ) {
						$openprint::log->debug("Max Impo $p => $max_impositions{$p}out");
					}# end foreach
				} # end if
				if ( sets::isin( $imp->pages(), \@dont_do_pages ) and ($$sig_specs{'chkOverridePageQuantity'.$qty_index} ne 'Y') ) {
#$imp->dispay('In dont do pages');
					next;
				} # end if
				if ( $$sig_specs{'PreviousImposition'} and ( $$sig_specs{'PreviousImposition'} > $imp->imposition() ) ) {
#$imp->display("Previous Imposition");
					next;
				} # end if
				if ( ( $$sig_specs{'chkOverridePageQuantity'.$qty_index} eq 'Y' ) and ( $imp->pages() != $$sig_specs{'PageQuantity'.$qty_index} ) ) {
					$openprint::log->debug("Doesn't match page quantity override " . $imp->pages() . ' != ' . $$sig_specs{'PageQuantity'.$qty_index}) if $debug;
					next;
				} # end if
				if (($max_pages >= $imp->pages() ) and ($$sig_specs{'chkOverridePageQuantity'.$qty_index} ne 'Y') ) {
# Only do this if not sheet size overrides
#$imp->display("Max paeages: $max_pages >= " . $imp->pages() );
					next;
				} elsif ($max_impositions{$imp->pages()}/2 > $imp->imposition()) {
# Only do this if not sheet size overrides
#$imp->dispay('Ma imposition!');
					next;
				} # end if

			} # end if SpreadLayout
			push @results, $imp;
		} # end foreach imp

		my %imps;
		foreach my $imp ( @results ) {
			my $add = 1;
			my $Paper = $imp->Paper();

			my $stock_qty = $qty/$imp->imposition();
			if ( $Paper->type() eq 'Roll' ) {
# Convert to weight
				$stock_qty *= $Paper->area() * $Paper->wpsi();
			} # end if
			$stock_qty += $$PaperCounts{$Paper->to_string()};
			my %SmallerPrice = $Paper->get_price($stock_qty > $Paper->minimum_order_weight() ? $stock_qty : $Paper->minimum_order_weight() );

			if ( $SpreadLayout > 0 ) {
				if ( $imp->runstyle() eq 'Work & Tumble' ) {
					my $str = sprintf('%d=%dx%d %dx%d-%s-%s', @$imp{'pages','spread_columns','spread_rows','columns','rows'}, 'Work & Turn', $$imp{'image_orientation'} );
					if ( $imps{$str} ) {
						for ( my $j = 0; $j < @{$imps{$str}}; $j += 1 ) {
							my $I = $imps{$str}[$j];
							my %BiggerPrice = $I->Paper()->get_price($stock_qty);
							if ( ( $I->Paper()->area() <= $Paper->area() )
									and ( $I->Paper()->minimum_order_weight() <= $Paper->minimum_order_weight() )
									and ( (1*$BiggerPrice{'100lb'}) <= (1*$SmallerPrice{'100lb'}) )
									and ( ( ! $I->Paper()->is_cut() ) or ( $Paper->is_cut() ) )
							   ) {
								$add = 0;
							} # end if
						} # end for
					} # end if $imps{$str}
				} elsif ( $imp->runstyle() eq 'Work & Turn' ) {
					my $str = sprintf('%d=%dx%d %dx%d-%s-%s', @$imp{'pages','spread_columns','spread_rows','columns','rows'}, 'Work & Tumble', $$imp{'image_orientation'} );
					if ( $imps{$str} ) {
						for ( my $j = 0; $j < @{$imps{$str}}; $j += 1 ) {
							my $I = $imps{$str}[$j];
							my %BiggerPrice = $I->Paper()->get_price($stock_qty);
							if ( ( $I->Paper()->area() >= $Paper->area() )
									and ( $I->Paper()->minimum_order_weight() >= $Paper->minimum_order_weight() )
									and ( (1*$BiggerPrice{'100lb'}) >= (1*$SmallerPrice{'100lb'}) )
									and ( $I->Paper()->is_cut() or ! $Paper->is_cut() )
							   ) {
								splice @{$imps{$str}}, $j, 1;
								$j -= 1;
							} # end if
						} # end for
					} # end if $imps{$str}
				} # end if

				my $str = sprintf('%d=%dx%d %dx%d-%s-%s', @$imp{'pages','spread_columns','spread_rows','columns','rows','runstyle','image_orientation'} );
				if ( $imps{$str} ) {
					for ( my $j = 0; $j < @{$imps{$str}}; $j += 1 ) {
						my $I = $imps{$str}[$j];

						if ( ($$sig_specs{'chkOverrideSheetSize'.$qty_index} eq 'Y') and ( $I->Paper()->width() == $$sig_specs{"OverrideStockWidth$qty_index"}) and ( $I->Paper()->height() == $$sig_specs{"OverrideStockHeight$qty_index"} )) {
							next;
						} elsif ( ( $$sig_specs{'OverrideCutOff'.$qty_index} eq 'Y' ) and ( $I->Paper()->height() == $$sig_specs{"CutOff$qty_index"} ) ) {
							next;
						} # end if
						my %BiggerPrice = $I->Paper()->get_price($stock_qty> $I->Paper()->minimum_order_weight() ? $stock_qty : $I->Paper()->minimum_order_weight());
						if ( ( $I->Paper()->area() >= $Paper->area() )
								and ( $I->Paper()->minimum_order_weight() >= $Paper->minimum_order_weight() )
								and ( (1*$BiggerPrice{'100lb Total'}) >= (1*$SmallerPrice{'100lb Total'}) )
								and ( $I->Paper()->is_cut() or ! $Paper->is_cut() )
						   ) {
							splice @{$imps{$str}}, $j, 1;
							$j -= 1;
if ( 0 ) {
                            $openprint::log->debug( "Dropping $BiggerPrice{'100lb Total'} " . $I->Paper()->minimum_order_weight() . " $SmallerPrice{'100lb Total'}" . $Paper->minimum_order_weight() );
                            $I->display();
                            $imp->display();
}

						} elsif ( ( $I->Paper()->area() <= $Paper->area() )
								and ( $I->Paper()->minimum_order_weight() <= $Paper->minimum_order_weight() )
								and ( (1*$BiggerPrice{'100lb Total'}) <= (1*$SmallerPrice{'100lb Total'}) )
								and ( ( ! $I->Paper()->is_cut() ) or ( $Paper->is_cut() ) )
								) {
							$add = 0;
if ( 0 ) {
                            $openprint::log->debug( "Not adding $BiggerPrice{'100lb Total'} " . $I->Paper()->minimum_order_weight() . " $SmallerPrice{'100lb Total'}" . $Paper->minimum_order_weight() );
                            $I->display();
                            $imp->display();
}

						} elsif ( 0 ) {
							$openprint::log->debug( "Not Dropping $BiggerPrice{'100lb'} $SmallerPrice{'100lb'}");
							$I->display();
							$imp->display();
						} # end if
					} # end for
				} # end if $imps{$str}
				push @{$imps{$str}}, $imp if $add;
			} else { # No SpreadLayout
				if ( $imp->runstyle() eq 'Work & Tumble' ) {
					my $str = sprintf('%d=%dx%d %s %s', @$imp{'imposition','columns','rows'}, 'Work & Turn', $$imp{'image_orientation'} );
					if ( $imps{$str} ) {
						for ( my $j = 0; $j < @{$imps{$str}}; $j += 1 ) {
							my $I = $imps{$str}[$j];
							if ( ($$sig_specs{'chkOverrideSheetSize'.$qty_index} eq 'Y') and ( $I->Paper()->width() == $$sig_specs{"OverrideStockWidth$qty_index"}) and ( (! $$sig_specs{"OverrideStockHeight$qty_index"} ) or $I->Paper()->height() == $$sig_specs{"OverrideStockHeight$qty_index"} )) {
								next;
							} elsif ( ( $$sig_specs{'OverrideCutOff'.$qty_index} eq 'Y' ) and ( $I->Paper()->height() == $$sig_specs{"CutOff$qty_index"} ) ) {
								next;
							} # end if
							my %BiggerPrice = $I->Paper()->get_price($qty/$I->imposition());
							if ( ( $I->Paper()->area() <= $Paper->area() )
									and ( $I->Paper()->minimum_order_weight() <= $Paper->minimum_order_weight() )
									and ( (1*$BiggerPrice{'100lb'}) <= (1*$SmallerPrice{'100lb'}) )
									and ( ( ! $I->Paper()->is_cut() ) or ( $Paper->is_cut() ) )
							   ) {
								$add = 0;
							} # end if
						} # end for
					} # end if overriden or not or cached
				} elsif ( $imp->runstyle() eq 'Work & Turn' ) {
					my $str = sprintf('%d=%dx%d %s %s', @$imp{'imposition','columns','rows'}, 'Work & Turn', $$imp{'image_orientation'} );
					if ( $imps{$str} ) {
						for ( my $j = 0; $j < @{$imps{$str}}; $j += 1 ) {
							my $I = $imps{$str}[$j];
							if ( ($$sig_specs{'chkOverrideSheetSize'.$qty_index} eq 'Y') and ( $I->Paper()->width() == $$sig_specs{"OverrideStockWidth$qty_index"}) and ( (! $$sig_specs{"OverrideStockHeight$qty_index"} ) or $I->Paper()->height() == $$sig_specs{"OverrideStockHeight$qty_index"} )) {
								next;
							} elsif ( ( $$sig_specs{'OverrideCutOff'.$qty_index} eq 'Y' ) and ( $I->Paper()->height() == $$sig_specs{"CutOff$qty_index"} ) ) {
								next;
							} # end if
							my %BiggerPrice = $I->Paper()->get_price($qty/$I->imposition());
							if ( ( $I->Paper()->area() >= $Paper->area() )
									and ( $I->Paper()->minimum_order_weight() >= $Paper->minimum_order_weight() )
									and ( (1*$BiggerPrice{'100lb'}) >= (1*$SmallerPrice{'100lb'}) )
									and ( ! ( ( ! $I->Paper()->is_cut() ) and $Paper->is_cut() ) )
							   ) {
								splice @{$imps{$str}}, $j, 1;
								$j -= 1;
							} # end if
						} # end for
					} # end if overriden or not or cached
				} # end if
				my $str = sprintf('%d=%dx%d %s %s', @$imp{'imposition','columns','rows','runstyle','image_orientation'} );
				if ( $imps{$str} ) {
					for ( my $j = 0; $j < @{$imps{$str}}; $j += 1 ) {
						my $I = $imps{$str}[$j];

						if ( ($$sig_specs{'chkOverrideSheetSize'.$qty_index} eq 'Y') and ( $I->Paper()->width() == $$sig_specs{"OverrideStockWidth$qty_index"}) and ( (! $$sig_specs{"OverrideStockHeight$qty_index"} ) or $I->Paper()->height() == $$sig_specs{"OverrideStockHeight$qty_index"} )) {
							next;
						} elsif ( ( $$sig_specs{'OverrideCutOff'.$qty_index} eq 'Y' ) and ( $I->Paper()->height() == $$sig_specs{"CutOff$qty_index"} ) ) {
							next;
						} # end if
						my %BiggerPrice = $I->Paper()->get_price($qty/$I->imposition());
						if ( ( $I->Paper()->area() >= $Paper->area() )
								and ( $I->Paper()->minimum_order_weight() >= $Paper->minimum_order_weight() )
								and ( (1*$BiggerPrice{'100lb'}) >= (1*$SmallerPrice{'100lb'}) )
								and ( ! ( ( ! $I->Paper()->is_cut() ) and $Paper->is_cut() ) )
						   ) {
							splice @{$imps{$str}}, $j, 1;
					$j -= 1;
				} elsif ( ( $I->Paper()->area() < $imp->Paper()->area() )
						and ( $I->Paper()->minimum_order_weight() <= $Paper->minimum_order_weight() )
						and ( (1*$BiggerPrice{'100lb'}) <= (1*$SmallerPrice{'100lb'}) )
						and ( ( ! $I->Paper()->is_cut() ) or ( $Paper->is_cut() ) )
						) {
					$add = 0;
				} elsif ( 0 ) {
					$openprint::log->debug( "Not Dropping $BiggerPrice{'100lb'} $SmallerPrice{'100lb'}");
					$I->display();
					$imp->display();
				} # end if
			} # end for
		} # end if overriden or not or cached
		push @{$imps{$str}}, $imp if $add;
	} # end if ServerLaoutout
} # end foreach imp
@impositions = map {@{$_}} values %imps;
} # end if using cache=

$log->debug("Press Impositions after filtering: " . @{$impositions{$Press->id()}} ) if $debug;
if ( $$sig_specs{'versions'} > 1 and @impositions < 30 ) {
	$openprint::log->debug("Calling do_versions, # of imps: " . @impositions ) if $debug;
	@impositions = openprint::imposition::do_versions( $versions, \@impositions );
	$openprint::log->debug("Back from do_versions, # of imps: " . @impositions ) if $debug;
} # end if
# Gives us both inline and offline folding options
if ( $$project{'HasFolding'} and ( $Press->Specification('Folding Capable') eq 'Y' ) ) {
	@impositions = map { openprint::Estimating::Folding::impositions( $Project, $_, $$project{'FoldingSpecs'}, $sig_specs, $qty_index ) } @impositions;
	$openprint::log->debug("Impositions for Press: " . $Press->strid() . ' after folding:' . @impositions) if $debug;
} # end if Folding

if ( $debug or 1 ) {
	$openprint::log->debug($$sig_specs{'txtUnspecifiedPageQuantity'.$qty_index} . " Press: " .$Press->strid() . ' # ' . @impositions );
	foreach my $imp ( @impositions ) {
		$imp->display();
	} # end foreach
} # end if
$openprint::log->debug("Number of impositions to consider for " . $Press->strid() . ': ' . scalar @impositions) if $debug;
if ( $$sig_specs{'chkOverrideImposition'.$qty_index} eq 'Y' ) {
	my $found = 0;
	foreach my $I ( @impositions ) {
		if ( $I->imposition() == $$sig_specs{'txtImposition'.$qty_index} ) {
			$found = 1;
		} # end if
	} # end foreach I
	if ( ! $found ) {
		my @i;
		foreach my $I ( openprint::imposition::get_all_impositions( @impositions ) ) {
			if ( $I->imposition() == $$sig_specs{'txtImposition'.$qty_index} ) {
				push @i, $I;
			} # end if
		} # end foreach I
		@impositions = @i;
	} # end if
} # end if

return @impositions;
} # end sub calculate_impositions

sub get_project_price {
	my ( $Project, $service_index, $project, $service_specs, $sig_specs, $qty, $qty_index, $possible_presses, $printing_specs, $versions, $PlateCounts, $PaperCounts, $previous_forms_cache, $signatures, $best_price, $recursion_depth ) = @_;
#$openprint::log->debug("******** get_project_price");
	my %previous_forms_cache;
	my %best_price;
	$best_price{'Comparison Cost'} = $best_price if $best_price;

	foreach my $P ( $$sig_specs{'chkOverridePress'.$qty_index} eq 'Y' ? openprint::Equipment::find_one('strid'=>$$sig_specs{'ddmPress'.$qty_index} ) : ('', @$possible_presses) ) {
		my $Press;
		if ( ! $P ) {
			if ( $impositions{''} and @{$impositions{''}} ) {
				$Press = $impositions{''}[0]->Press();
			} # end if
		} else {
			$Press = $P;
		} # end if
		next if ! $Press;

		# When calculating the get_project_price for remaining sigs, we must make sure that we stay with the same type
		if ( $$sig_specs{'PrintingTypes'} and @{$$sig_specs{'PrintingTypes'}} and ($$sig_specs{'OverridePrintingType'.$qty_index} ne 'Y' ) and ! sets::isin( $Press->specification('Printing Type'), $$sig_specs{'PrintingTypes'} ) ) {
			$openprint::log->debug("Wrong type " . $Press->strid() . " : " . $Press->specification('Printing Type') . ': want ' . join(',', @{$$sig_specs{'PrintingTypes'}} ) ) if $debug;
			next;
		} # end if
		foreach my $imp ( calculate_impositions( $Project, $P, $sig_specs, $qty_index, $qty, $PaperCounts, $versions, $project ) ) {

			$$sig_specs{'ddmRunStyle'.$qty_index} = $imp->runstyle();
			$$sig_specs{'ddmPress'.$qty_index} = $Press->strid();
			$$sig_specs{'PageQuantity'.$qty_index} = $imp->pages();
			my %previous_forms_cache = %$previous_forms_cache;
			my $hash_key = join(',', $Press->strid(), $imp->runstyle(), $imp->pages(), $imp->imposition() );
			$$sig_specs{'PreviousForms'.$qty_index} = $previous_forms_cache{$hash_key};
			$previous_forms_cache{$hash_key} += 1;
my $recurse = 0;

			my $services = $Project->services();
			my %PlateCounts = %$PlateCounts;
			my %PaperCounts = %$PaperCounts;

			# Imp still gets modified in calc_price, Folding adds Folder member
			$imp = $imp->copy();
#my $time = gettimeofday();
#$imp->display($recursion_depth . ' Starting');
			my $price = calc_price( $Project, $service_index, $imp, $project, $services, $sig_specs, $qty, $qty_index, \%PlateCounts );
#$imp->display("Actually calculating this imp $$price{'Comparison Cost'}");
#$openprint::log->debug("Main Calc Price time: " . ( sprintf('%.4f', tv_interval( [$time])*1000) ) .' usecs' );
#$openprint::log->debug( breakdown( $price, $sig_specs ) );
			if ( ! $$price{'complete'} ) {
				if ( $debug ) {
					$imp->display( 'Couldnt calculate initial price' );
				} # end if
				next;
			} # end if
			if ( %best_price and $best_price{'Comparison Cost'} <= $$price{'Comparison Cost'} ) {
				if ( $debug or 1) {
					$imp->display( "Too expensive $best_price{'Comparison Cost'} <= $$price{'Comparison Cost'}" );
				} # end if
				next; # next Impo
			} # end if
			my $Paper = $imp->Paper();

			if ( $$project{'HasProofs'} ) {
				# Add proof costs.  Proofs only depends on colours, equipment so doesn't need to be part of the rest of calc
				my %Results = openprint::Estimating::Proofs::signature_calc( $Project, $$project{'ProofsSpecs'}, $service_index, $sig_specs, $qty_index, undef, undef, $Press );
				$$price{'Comparison Cost'} += $Results{'Total'};
				$$price{'Proofs Breakdown'} .= $Results{'Breakdown'};
			} # end if

            $PlateCounts{$$price{'Plate Costs'}{'Plate ID'}} += $$price{'Plate Costs'}{'Plate Count'};
            $PlateCounts{'Blank'.$$price{'Plate Costs'}{'Plate ID'}} += $$price{'Plate Costs'}{'Blank Plates'};
			$PaperCounts{$Paper->to_string()} += $$price{'Stock Qty'};

			@{$$price{'Impositions'}} = @{$$sig_specs{'Impositions'}} if $$sig_specs{'Impositions'};
			push @{$$price{'Impositions'}}, $imp;

			my $upq = $$sig_specs{'txtUnspecifiedPageQuantity'.$qty_index} - $imp->pages();
			if ( $upq and $imp->pages() ) {
				my @signatures = @$signatures;
				my $s_id = $service_index;
				my %new_specs;
				my $last_sig_price = int($$price{'Comparison Cost'});

				while ( $upq > 0 ) {
					if ( $s_id ) {
						# Look for overrides first. 
						for ( my $j = 0; $j < @signatures; $j += 1 ) {
# This code can theortically unsort the sognatures, so we shouldn't really have special cases for when the s_id is greater than the current one.
							if ( $signatures[$j] != $s_id ) {
#$openprint::log->debug("Consider sig in overrides $s_id");
								my $sig_specs2 = openprint::service::get_specs_ref( $Project, $signatures[$j] );
								foreach my $override ( 'chkOverridePageQuantity','chkOverrideImposition', 'chkOverridePress','chkOverrideRunStyle' ) {
									if ( $$sig_specs2{$override.$qty_index} eq 'Y' ) {
										$s_id = $signatures[$j];
										splice @signatures, $j, 1;
										%new_specs = %{$sig_specs2};
#$openprint::log->debug("Found sig in overrides $override $s_id");
										last;
									} # end if
								} # end foreach override
								last if $s_id != $service_index;
			
							} else {
								splice @signatures, $j, 1;
								$j -= 1;
							} # end if
						} # end foreach

						# If we get here, @signatures has been cleaned out, and no overrides found.
						if ( ( $s_id == $service_index ) and @signatures ) {
							$s_id = shift @signatures;
							%new_specs = %{openprint::service::get_specs_ref( $Project, $s_id )};
# Not neccessary to empty the overrides, because we went looking for them above, and didn't find them
							#$openprint::log->debug("Found sig without  overrides $s_id");
						} # end if
					} # end if s_id, meaning dealing with existing sigs
# If we didn't get a new s_id, then we are using fake services
					if ( $s_id == $service_index ) {
							#$openprint::log->debug("Making fake service");
						$s_id = 0;
						%new_specs = %$service_specs;
# These will only have an effect if we get down to call get_project_price. If we get there, we are looking at a smaller # of pages, so might want a different press.
						$new_specs{'chkOverrideImposition'.$qty_index} = '';
						$new_specs{'chkOverridePageQuantity'.$qty_index} = '';
						$new_specs{'chkOverridePress'.$qty_index} = '';
						$new_specs{'chkOverrideRunStyle'.$qty_index} = '';
						$new_specs{'chkOverrideSheetSize'.$qty_index} = '';
					} # end if

# Need to update these too.  
					$new_specs{'PreviousForms'.$qty_index} = $previous_forms_cache{$hash_key};
					$new_specs{'txtUnspecifiedPageQuantity'.$qty_index} = $upq;

					my $additional_price;
					my $sig_price = {};
					my $sigs = 1;
					if ( $upq >= $imp->pages() 
						and ( ($new_specs{'chkOverridePageQuantity'.$qty_index} ne 'Y') or ($new_specs{'PageQuantity'.$qty_index} == $imp->pages()) ) 
						and ( ($new_specs{'chkOverrideImposition'.$qty_index} ne 'Y') or ($new_specs{'txtImposition'.$qty_index} == $imp->imposition()) ) 
						and ( ($new_specs{'chkOverridePress'.$qty_index} ne 'Y') or ($new_specs{'ddmPress'.$qty_index} eq $imp->Press()->strid()) )
						and ( ($new_specs{'chkOverrideRunStyle'.$qty_index} ne 'Y') or ($new_specs{'ddmRunStyle'.$qty_index} eq $imp->runstyle()) )
) {

				  		$sig_price = calc_price( $Project, $s_id, $imp, $project, $services, \%new_specs, $qty, $qty_index, \%PlateCounts );
$imp->display("additional calc_price this imp $$sig_price{'Comparison Cost'}");
						$additional_price = $$sig_price{'Comparison Cost'};

						if ( int($$sig_price{'Comparison Cost'}) == $last_sig_price ) {
							$sigs = int($upq/$imp->pages());

							$additional_price *= $sigs;

							$PaperCounts{$Paper->to_string()} += $sigs * $$sig_price{'Stock Qty'};
							foreach ( 1 .. $sigs ) {
								push @{$$price{'Impositions'}}, $imp;
								$previous_forms_cache{$hash_key} += 1;
							} # end foreach
							$upq = $upq % $imp->pages();
							$PlateCounts{$$sig_price{'Plate Costs'}{'Plate ID'}} += $sigs * $$sig_price{'Plate Costs'}{'Plate Count'};
							$PlateCounts{'Blank'.$$sig_price{'Plate Costs'}{'Plate ID'}} += $sigs * $$sig_price{'Plate Costs'}{'Blank Plates'};
						} else {
							$sigs += 1;
							$last_sig_price = int($$sig_price{'Comparison Cost'});
							$PaperCounts{$Paper->to_string()} += $$sig_price{'Stock Qty'};
							push @{$$price{'Impositions'}},$imp;
							$upq -= $imp->pages();
							$PlateCounts{$$sig_price{'Plate Costs'}{'Plate ID'}} += $$sig_price{'Plate Costs'}{'Plate Count'};
							$PlateCounts{'Blank'.$$sig_price{'Plate Costs'}{'Plate ID'}} += $$sig_price{'Plate Costs'}{'Blank Plates'};
							$previous_forms_cache{$hash_key} += 1;
						} # end if

					} else {
						# Not identical, so clear this so we get charged setups, etc
						$new_specs{'PreviousForms'.$qty_index} = 0;
$openprint::log->debug("Doing full calc when $upq >= " . $imp->pages() . ' ' . $new_specs{'PageQuantity'.$qty_index} ) if $upq >= $imp->pages();

						if ( ( $new_specs{'chkOverridePageQuantity'.$qty_index} eq 'Y' ) and ( $new_specs{'PageQuantity'.$qty_index} > $upq ) ) {
							$new_specs{'chkOverridePageQuantity'.$qty_index} = '';
						} # end if

						$new_specs{'PrintingTypes'} = [ $Press->specification('Printing Type') ];
						$new_specs{'PreviousStockType'} = $Paper->type();
						$new_specs{'PreviousGrainDirection'} = $imp->grain_direction();
						if ( $$imp{'Folder'} and ( $imp->Press()->id() == $$imp{'Folder'}->id() ) ) {
							#This is used in Folding to tell it not to mix impositions when inline folded
							$new_specs{'PreviousImposition'} = $$price{'FoldingImposition'};
						} # end if	
						$new_specs{'Impositions'} = $$price{'Impositions'};

						if ( $recursion_depth >= 3 ) {
							$imp->display('Recursion Depth :' . $recursion_depth ) if ( $debug or 1);
							$$sig_price{'complete'} = 0;
						} else {
$recurse = 1;
#$openprint::log->debug("Equipment override: ".$new_specs{'chkOverridePress'.$qty_index} );
#$openprint::log->debug("Page QUantity override: ".$new_specs{'chkOverridePageQuantity'.$qty_index} );
#$imp->display("get_projcetcalc_price this imp $best_price{'Comparison Cost'} $$price{'Comparison Cost'}");
							$sig_price = get_project_price( $Project, $s_id, $project, $service_specs, \%new_specs, $qty, $qty_index, $possible_presses, $printing_specs, $versions, \%PlateCounts, \%PaperCounts, \%previous_forms_cache, \@signatures, (%best_price ? $best_price{'Comparison Cost'} - $$price{'Comparison Cost'} : 0), $recursion_depth + 1 );
						} # end if
						$upq = 0;

# get_project_price is recursive so we are done
						if ( ( ! $$sig_price{'complete'} ) or ( ! $$sig_price{'Imposition'} ) ) {
							$$price{'complete'} = $$sig_price{'complete'} = 0;
							$additional_price = 10000000;
							$openprint::log->warn('Couldnt calculate full price');
						} else {
							@{$$price{'Impositions'}} = @{$$sig_price{'Impositions'}} if $$sig_price{'Impositions'};

							# Don't add stock weight because we likely have a different stock anyways.
							$PaperCounts{$$sig_price{'Imposition'}->Paper()->to_string()} += $$sig_price{'Stock Qty'};

							$PlateCounts{$$sig_price{'Plate Costs'}{'Plate ID'}} += $$sig_price{'Plate Costs'}{'Plate Count'};
							$PlateCounts{'Blank'.$$sig_price{'Plate Costs'}{'Plate ID'}} += $$sig_price{'Plate Costs'}{'Blank Plates'};
							$additional_price = $$sig_price{'Comparison Cost'};
							#$$price{'Paper Breakdown'} = $$sig_price{'Paper Breakdown'};
							# Will get included in AdditionalSignature Breakdown
							#$$price{'Stitching Breakdown'} = $$sig_price{'Stitching Breakdown'};
							#$$price{'PerfectBound Breakdown'} = $$sig_price{'PerfectBound Breakdown'};
							$$price{'AdditionalSignature Breakdown'} = $$sig_price{'AdditionalSignature Breakdown'};
						} # end if sig_price complete
					} # end if calc_price or get_project_price

					if ( (! $$sig_price{complete}) or ($additional_price < 0) ) {
$openprint::log->debug("Unable to calculate additional signatures Complete: $$sig_price{complete}, additional price: $additional_price $$sig_price{'Comparison Cost'}");
#$imp->display();
						$$price{'complete'} = 0;
						$$price{'AdditionalSignature Breakdown'} .= 'Unable to calculate additional signatures.<br/>';
						last;
					} # end if

					#$additional_price -= $$sig_price{'Plate Comparison Cost'};
					# Fills in the price for breakdown
					plate_cost( $sig_price, \%PlateCounts, $$sig_price{'Imposition'} );

					$$price{'Comparison Cost'} += $additional_price;
					#$additional_price += $$sig_price{'Plate Price'};
					#$additional_price += $$sig_price{'Blank Plate Price'};

					if ( $$sig_price{'Imposition'} ) {
						$$price{'AdditionalSignature Breakdown'} .= sprintf($sigs . ' Additional Sig %dpages %dout %s on %sx%s on %s %.2f', $$sig_price{'Imposition'}->pages(), $$sig_price{'Imposition'}->imposition(), $$sig_price{'Imposition'}->runstyle(), $$sig_price{'Imposition'}->Paper()->width(), $$sig_price{'Imposition'}->Paper()->height(), $$sig_price{'Imposition'}->Press()->strid(), $$price{'Comparison Cost'} ) . '<br/>';
						$$sig_price{'Comparison Cost'} = '';
						$$price{'AdditionalSignature Breakdown'} .= breakdown( $sig_price, $sig_specs );
					} else {
						$$price{'AdditionalSignature Breakdown'} .= 'Unable to calculate additional signatures.<br/>';
					} # end if

					if ( %best_price and check_price( $best_price{'Comparison Cost'}, $price, $sig_specs, $qty_index, $imp, 'Sig' ) ) {
#$openprint::log->debug("Worse than best: Best is " . $best_price{'Imposition'}->pages() .': ' . $best_price{'Comparison Cost'} . ' ours: ' . $imp->pages() . ': ' . $$price{'Comparison Cost'} );
#$best_price{'Imposition'}->display() if $best_price{'Imposition'};
#$imp->display();
						$$price{'complete'} = 1;
						$upq = 0;
						last;
					} # end if
				} # end while UnspecifiedPages
			} # end if UnspecifiedPageQuanitty
#$openprint::log->debug( 'calc_price: ' . sprintf('%.4f', tv_interval( [$starttime])*1000) . ' Complete: ' . $price{complete} );
			if ( ! $$price{complete} ) {
if ( $debug ) {
$openprint::log->debug("No price complete ");
$imp->display();
} # end if
				next;
			} # end if

			if ( %best_price and $best_price{'Comparison Cost'} <= $$price{'Comparison Cost'} ) {
#$openprint::log->debug("BLAH: $best_price{'Comparison Cost'} <= $$price{'Comparison Cost'}");
				next; # next Impo
			} # end if

if ( ! $recurse ) {
			my @paper_strings = keys %PaperCounts;
			if ( 1 == @paper_strings and $imp->Paper()->to_string() ne $paper_strings[0] ) {
$openprint::log->error("Different paper in count versus imposition: $paper_strings[0] ne " . $imp->Paper()->to_string() );
			} else {
				foreach my $k ( @paper_strings ) {
					$openprint::log->debug( "$k => $PaperCounts{$k}" );
				} # end 
			}

			foreach my $paper_string ( keys %PaperCounts ) {
				my $Paper = $Papers{$paper_string};
				if ( ! $Paper ) {
					$log->error("No Paper Object for $paper_string");
					foreach my $paper_string ( keys %Papers ) {
						$log->error("$paper_string $Papers{$paper_string}");
					} 
					next;
				} elsif ( $paper_string ne $Paper->to_string() ) {
$openprint::log->error("Different paper in count versus imposition: $paper_string ne " . $Paper->to_string() );
	
				} # end if

				if ( $Paper->full_packages() ) {
					my $sheets_per_package = $Paper->sheets_per_package();
					if ( $sheets_per_package ) {
						$PaperCounts{$paper_string} = $sheets_per_package * ceil( $PaperCounts{$paper_string}/$sheets_per_package);
					} # end if
				} # end if

#$openprint::log->debug("Pricing Paper: Minimum Order: " . $Paper->minimum_order() );
				if ( $Paper->minimum_order() ) {
					# Assume sheets for sheets, lbs for Rolls
					if ( $Paper->minimum_order() > $PaperCounts{$paper_string} ) { # Must be a roll
						$PaperCounts{$paper_string} = $Paper->minimum_order();
					} # end if
				} # end if
				my $weight = $Paper->type() eq 'Sheet' ? ceil($PaperCounts{$paper_string} * $Paper->sheet_weight()) : $PaperCounts{$paper_string};
				my %paper_price = $Paper->get_price( $weight );
				$paper_price{'Total'} = sprintf('%.2f', $paper_price{'100lb Price'} * $weight / 100 );
				$$price{'Comparison Cost'} += $paper_price{'Total'};
				$$price{'Stock Total'} += $paper_price{'Total'};
				$$price{'Paper Breakdown'} .= sprintf('Stock: %s %s SPP:%s Minimum: %s %slbs * %.2f/100lbs = $%.2f<br/>', $Paper->type() eq 'Sheet' ? $PaperCounts{$paper_string} .'sheets' : $PaperCounts{$paper_string}.'lbs', $Paper->to_string(), $Paper->sheets_per_package(), $Paper->minimum_order(), $weight, @paper_price{'100lb Price','Total'} );
			} # end foreach Paper in PaperCounts
#$openprint::log->debug($$price{'Paper Breakdown'});
#$openprint::log->debug("Comparison: $$price{'Comparison Cost'}");

			if ( $$sig_specs{'rdbSuppliedStock'} eq 'Y' ) {
				if ( my %SuppliedPaperPrice = openprint::service::get_price_object( 'Supplied'.$Paper->type(), undef, undef ) ) {
					if ( lc $SuppliedPaperPrice{'units'} eq 'per 100lbs' ) {
						$SuppliedPaperPrice{'Total'} = $SuppliedPaperPrice{'Price'} * $$price{'Stock Weight'} / 100;
					} elsif ( lc $SuppliedPaperPrice{'units'} eq 'per sheet' ) {
						$SuppliedPaperPrice{'Total'} = $SuppliedPaperPrice{'Price'} * $$price{'Gross Sheet Count'};
					} elsif ( lc $SuppliedPaperPrice{'units'} eq 'per m' ) {
						$SuppliedPaperPrice{'Total'} = $SuppliedPaperPrice{'Price'} * $$price{'Gross Sheet Count'}/1000;
					} # end if
					$$price{'SuppliedPaperPrice'} = \%SuppliedPaperPrice;
					$$price{'Comparison Cost'} += $SuppliedPaperPrice{'Total'};
					$$price{'Total Cost'} += $SuppliedPaperPrice{'Total'};
				} # end if
			} elsif ( ! openprint::ServiceType::find('name'=>'Paper') ) {
				my %paper_price = $Paper->get_price( $$price{'Stock Weight'} );
				$paper_price{'Total'} = sprintf('%.2f', $paper_price{'100lb Price'} * $$price{'Stock Weight'} / 100 );
				@$price{'Paper Cost', 'Paper Price', 'Paper Total'} = @paper_price{'100lb Cost', '100lb Price', 'Total'};
				$$price{'Total Cost'} += $$price{'Paper Total'};
			} # end if

			if ( $Paper->type() eq 'Roll' and sets::isin('Sheet', split(',', $Press->specification('Feed') ) ) and ! $$project{'roll2sheetcharged'} ) {
				$$price{'Roll2SheetCharge'} = openprint::service::get_price( 'Roll2Sheet', undef, $Press );
				$$price{'Comparison Cost'} += $$price{'Roll2SheetCharge'};
				$$price{'Total Cost'} += $$price{'Roll2SheetCharge'};
				$$price{'Setup Total'} += $$price{'Roll2SheetCharge'};
			} # end if

#$openprint::log->debug("After plates: $$price{'Plate Comparison Cost'} $$price{'Comparison Cost'}");
			# plate cost basically fills in the breakdown with appropriate, discounted data
			plate_cost( $price, \%PlateCounts, $imp );
			# This actually adds the plate costs 
			foreach my $plate_id ( keys %PlateCounts ) {
				if ( my $Material = openprint::Material::find_one( 'name'=>$plate_id ) ) {
					my %plate_price = $Material->get_price( $PlateCounts{$plate_id}, undef );
					$$price{'Plate Comparison Cost'} += $plate_price{'Price'} * $PlateCounts{$plate_id};
					$$price{'Comparison Cost'} += $plate_price{'Price'} * $PlateCounts{$plate_id};
				} # end if
			} # end foreach plate_id
#$openprint::log->debug("After plates: $$price{'Plate Comparison Cost'} $$price{'Comparison Cost'}");

			#if ( ! $upq ) {
				# The idea is to only calc these on the last sig
				if ( ($$services{'LoopStitching'} or $$services{'SaddleStitching'}) and ($$sig_specs{'txtSignatureType'} ne 'Cover Spreads') ) {
					my @all_impositions;
					foreach my $sig_id ( $Project->signatures() ) {
						next if $sig_id >= $service_index;
						my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
						my $I = new openprint::Imposition();
						$I->load( $sig_specs, $qty_index );
						push @all_impositions, $I;
					}
					push @all_impositions, @{$$price{'Impositions'}};
					
#my $starttime = gettimeofday();
					my $results = openprint::Estimating::Stitching::signature_calc( $Project, $$project{'HasStitching'}, $$project{'StitchingSpecs'}, $qty_index, $$project{'FoldingSpecs'}, $service_index, @all_impositions );
					if ( $$results{'Status'} eq 'uncalculated' ) {
						$$price{'Stitching Breakdown'} .= "Stitching error: $$results{'alert'} <br/>";
#$price{'Stitching Breakdown'} .= "Stitching error: $$results{'alert'} <br/>" . $$project{'StitchingSpecs'}{'hdnBreakdown'.$qty_index};
						$$price{'Comparison Cost'} += 10000000; # Can't stich this on
							$$price{'Stitching Cost'} = 10000000;
					} else {
						$$price{'Stitching Breakdown'} .= sprintf('Stitching (%s) (%s) Price: $%.2f<br/>', @$results{'Status','alert','Price'} );
						$$price{'Stitching Cost'} = $$results{'Price'};
						$$price{'Comparison Cost'} += $$results{'Price'};
#$openprint::log->debug("After Stitching $$price{'Comparison Cost'} $$price{'Stitching Cost'}");
					} # end if
#$openprint::log->debug( 'Stitching Calc: ' . sprintf('%.4f', tv_interval( [$starttime])*1000) );
				} # end if

				if ( $$services{'PerfectBound'} and $$sig_specs{'txtSignatureType'} ne 'Cover Spreads') {
#my $starttime = gettimeofday();
					my @Impositions = @{$$price{'Impositions'}};

					foreach my $sig_id ( $Project->signatures() ) {
						my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
# Don't try to load uncalculated sigs.  They can't count, might turn it 1 out
						next if ! $$sig_specs{'txtImposition'.$qty_index};
						next if $$sig_specs{'Group'} == 1;
						next if ( ($$sig_specs{'Group'} == $$service_specs{'Group'}) and ($sig_id >= $service_index) );
#$openprint::log->debug("PerfectBond: Group: $$sig_specs{'Group'} == $$service_specs{'Group'} and $sig_id >= $service_index");
						my $I = new openprint::Imposition();
						$I->load( $sig_specs, $qty_index );
						push @Impositions, $I;					
					} # end foreach sig_id
					my $results = openprint::Estimating::PerfectBound::signature_calc( $Project, $$project{'HasPerfectBound'}, $$project{'PerfectBoundSpecs'}, $qty_index, $$project{'FoldingSpecs'}, $service_index, @Impositions );
					if ( $$results{'Status'} eq 'uncalculated' ) {
						$$price{'PerfectBound Breakdown'} .= "PerfectBound error: $$results{'alert'}<br/>";
						$$price{'Comparison Cost'} += 1000000;
						$$price{'PerfectBound Cost'} = 1000000;
					} else {
						$$price{'PerfectBound Breakdown'} .= sprintf('PerfectBound (%dout) Price: $%.2f<br/>%s<br/>', @$results{'Imposition','Price','alert'} );
						$$price{'PerfectBound Cost'} = $$results{'Price'};
						$$price{'Comparison Cost'} += $$results{'Price'};
					} # end if
#$openprint::log->debug( 'PerfectBound Calc: ' . sprintf('%.4f', tv_interval( [$starttime])*1000) );
				} # end if PerfectBound
			#} # end if PerfectBound
} # end if ! recurse

			if ( $$price{'Comparison Cost'} < 0 ) {

				$openprint::log->debug("Negative price! $best_price{'Comparison Cost'} <= $$price{'Comparison Cost'}") if 1 or $debug;
#$imp->display();
			} elsif ( %best_price and $best_price{'Comparison Cost'} <= $$price{'Comparison Cost'} ) {
#$openprint::log->debug("No good, more expensive $best_price{'Comparison Cost'} <= $$price{'Comparison Cost'}") if 1 or $debug;
#$best_price{'Imposition'}->display() if $best_price{'Imposition'};
#$openprint::log->debug( breakdown( \%best_price, $specs ) );
#$imp->display();
#$openprint::log->debug( breakdown( $price, $specs ) );
			} else {
#$imp->display();
#$openprint::log->debug("Got better: $best_price{'Comparison Cost'} > $$price{'Comparison Cost'}" );
#if ( %best_price ) {
#$best_price{'Imposition'}->display() if $best_price{'Imposition'};
##$openprint::log->debug( breakdown( \%best_price, $specs ) );
#}
#$imp->display();
#$openprint::log->debug( breakdown( $price, $specs ) );
				%best_price = %{$price};
#$imp->display();
#keep track of the best price we have found so far.
# now that we have the pricing info arrange it in a hash and store it for later.
#$best_price{'Imposition'} = $imp;
				$best_price{'Press'} = $Press;
			} # end if 
#$$imp{'PriceHash'} = $price;
#$$imp{'Total'} = $$price{'Total Cost'};
#$$imp{'Comparison'} = $$price{'Comparison Cost'};
		} # end foreach imposition
	} # end foreach Press
	if ( ! %best_price ) {
		return;
	} else {
#$openprint::log->warn( "After calc imp: " . $best_price{'Imposition'}->imposition() );
	} # end if
	return \%best_price;
} # end sub get_project_price

sub plate_cost {
	my ( $price, $PlateCounts, $imp ) = @_;

	my %plate_price;
	if ( my @materials = openprint::Material::find( 'name'=>$$price{'Plate Costs'}{'Plate ID'} ) ) {
		%plate_price = $materials[0]->get_price( $$PlateCounts{$$price{'Plate Costs'}{'Plate ID'}}, undef );
	} # end if
	$$price{'txtPlateQuantity'} = $$price{'Plate Costs'}{'Plate Count'};
	$$price{'Plate Cost'} = $plate_price{'Price'};
	$$price{'Plate Price'} = $plate_price{'Price'} * $$price{'Plate Costs'}{'Plate Count'};
	$$price{'Total Cost'} += $$price{'Plate Price'};
	$$price{'PlateID'} = $$price{'Plate Costs'}{'Plate ID'};

	if ( $$price{'Plate Costs'}{'Blank Plates'} ) {
		if ( my @materials = openprint::Material::find( 'name'=>'Blank'.$$price{'Plate Costs'}{'Plate ID'} ) ) {
			my %blank_plate_price = $materials[0]->get_price( $$PlateCounts{'Blank'.$$price{'Plate Costs'}{'Plate ID'}}, undef );
			$$price{'Plate Costs'}{'Blank Price'} = $blank_plate_price{'Price'};
		} # end if
		$$price{'txtBlankPlateQuantity'} = $$price{'Plate Costs'}{'Blank Plates'};
		$$price{'Blank Plate Price'} = $$price{'Plate Costs'}{'Blank Plates'} * $$price{'Plate Costs'}{'Blank Price'};
		$$price{'Total Cost'} += $$price{'Blank Plate Price'};
	} # end if
	if ( $$price{'Plate Costs'}{'Plate Type'} eq 'Conventional' ) {
		$$price{'Film Cost'} = openprint::service::get_price( 'Film', $imp->Paper()->area() * $$PlateCounts{$$price{'Plate Costs'}{'Plate ID'}}, undef ) * $imp->Paper()->area() * $$PlateCounts{$$price{'Plate Costs'}{'Plate ID'}};
		$$price{'Comparison Cost'} += $$price{'Film Cost'};
		$$price{'Total Cost'} += $$price{'Film Cost'};
	} # end if

} # end sub plate_cost

sub check_price {
	my ( $price_to_beat, $price, $specs, $qty_index, $Imposition, $text ) = @_;

	return 0 if ! $price_to_beat;
	my $p = $$price{'Comparison Cost'};
#if ( $$specs{'txtUnspecifiedPageQuantity'.$qty_index} ) {
#$p *= ( 1 + ($$specs{'totalSpreads'}-$Imposition->spreads())/$Imposition->spreads() );
#$p *= ( 1 + $$specs{'txtUnspecifiedPageQuantity'.$qty_index}/$Imposition->spreads() );
#} # end if

#if ( $price_to_beat > $p ) {
#$openprint::log->debug("Check Price: $$price{'Comparison Cost'} $p > $price_to_beat: " . $Imposition->imposition().'out ' . $Imposition->spreads() .'spreads on ' . $Imposition->paper()->width().'x'.$Imposition->paper()->height(). " : $text") if $debug;
	if ( $price_to_beat > $$price{'Comparison Cost'} ) {
#$openprint::log->warn("Check Price: $$price{'Comparison Cost'} $p <= $price_to_beat: " . $Imposition->imposition().'out ' . $Imposition->spreads() .'spreads on ' . $Imposition->paper()->width().'x'.$Imposition->paper()->height(). " : $text") if $debug;
		return 0;
	} # end if
	$openprint::log->warn("Check Price: $$price{'Comparison Cost'} $p > $price_to_beat: " . $Imposition->imposition().'out ' . $Imposition->spreads() .'spreads on ' . $Imposition->paper()->width().'x'.$Imposition->paper()->height(). " : $text") if $debug and 0;
	return 1;
} # end sub

# Takes and Imposition object, and calculates a Price Object.
# Does not need to take folding or Cutting into account, as those were chosen separately
sub calc_price {
	my ( $Project, $service_index, $Imposition, $project, $services, $specs, $qty, $qty_index, $PlateCounts ) = @_;

	my $Paper = $Imposition->Paper();
	my $Press = $Imposition->Press();

# It's ok to do this, because $$specs is either a copy, or will be reset before being returned
	$$specs{'SpreadRows'.$qty_index} = $$Imposition{spread_rows};
	$$specs{'SpreadCols'.$qty_index} = $$Imposition{spread_columns};
	$$specs{'hdnImageOrientation'.$qty_index} = $$Imposition{image_orientation};
	$$specs{"PageQuantity$qty_index"} = $Imposition->pages();
	$$specs{'txtStockGSM'} = $Paper->gsm();
	$$specs{'txtSpecificStockCalliper'} = $Imposition->Paper()->calliper();

	my %price;
	$price{'Imposition'} = $Imposition;

	my @colours = ();
	$price{'WorkTurn Dry Charge'} = 0;

#$log->debug("\n\n************ START OF CALC PRINT PRICE QTY: $qty 1: @$side_one_colours, @$side_two_colours CAL: $paper_calliper DT: $dry_trap  STYLE: $run_style ********* \n\n\n");
	my ( $is_sheetwork, $is_perfecting );
	if ( sets::isin( $$Imposition{runstyle},['Sheet Work','Web'] ) ) {
		$is_sheetwork = 1;
		$is_perfecting = 0;
		@colours = @{$$project{'side_one_colours'}};
		if ( ( $$specs{'sides_the_same'} eq 'Y' ) and ( $$Imposition{runstyle} eq 'Sheet Work' ) ) {
		} else {
			push @colours, @{$$project{'side_two_colours'}};
		} # end if

	} elsif ( sets::isin( $$Imposition{runstyle}, ['Work & Turn','Work & Tumble'] ) ) {
		$is_sheetwork = 0;
		$is_perfecting = 0;
		$price{'WorkTurn Dry Charge'} = openprint::service::get_price( 'WTDrying', $Paper->grade(), $Press );
		@colours = @{$$project{'filtered_colours'}};
	} elsif ( $$Imposition{runstyle} eq 'Perfecting' ) {
#$log->debug("************ WE HAVE PERFECTING ****************");
		$is_sheetwork = 1;
		$is_perfecting = 1;
		@colours = @{$$project{'side_one_colours'}};
		if ( $$specs{'sides_the_same'} ne 'Y' ) {
			push @colours, @{$$project{'side_two_colours'}};
		} # end if
	} else {
		$openprint::log->error("\n\n\n********* UNKNOWN RUNSTYLE: in function 'get_project_price' ****************\n\n\n");
	} # end if

	my $imposition = $$Imposition{imposition};
	if ( $$specs{'Versions'} > 1 ) {
# When W&T, each half has to be a multiple of the versions
		if ( sets::isin( $$Imposition{runstyle}, ['Work & Turn','Work & Tumble'] ) ) {
			$imposition = int($imposition/2);
			if ( $imposition < $$specs{'Versions'} ) {
#i.e. if imp = 12 and ver = 30 then only 10 of the slots get used.
				$imposition = $$specs{'Versions'} / ceil($$specs{'Versions'} / $imposition);
			} else {
#i.e. if imp = 72 and ver = 30 then only 60 of the slots get used.
				$imposition = int($imposition / $$specs{'Versions'}) * $$specs{'Versions'};
			} # end 
			$imposition *= 2;
		} else {
# if we have a multiple version project, we may need to adjust the sheet count because, we may  not be able to use all of the slots.
			if ( $imposition < $$specs{'Versions'} ) {
#i.e. if imp = 12 and ver = 30 then only 10 of the slots get used.
				$imposition = $$specs{'Versions'} / ceil($$specs{'Versions'} / $imposition);
			} else {
#i.e. if imp = 72 and ver = 30 then only 60 of the slots get used.
				$imposition = int($imposition / $$specs{'Versions'}) * $$specs{'Versions'};
			} # end 
		} # end 
	} # end if 

	my $net_sheets;
	if ( $$specs{'OverrideBase'.$qty_index} eq 'Y' ) {
		$net_sheets = $$specs{'OverBase'.$qty_index};
	} else {
		$net_sheets = ceil($qty / $imposition);
		$net_sheets *= $$specs{'Versions'} if $$specs{'Versions'};
		$net_sheets *= $Paper->parts() if $Paper->parts();
	} # end if
#Initially we calculate based on colours, but really we need to calculate based on plates, which we will do once we figure out how many plates we need.
	my $min_overs = $Press->specification( 'Overs Minimum', scalar @colours );
	my $overs = 0;

	my $setup_rate;
	if ( $$project{'print_sides'} == 1 ) {
		$setup_rate = $Press->specification( 'MakeReady Overs Rate One Side', scalar @colours );
	} else {
		$setup_rate = $Press->specification( 'MakeReady Overs Rate ' . $$Imposition{'runstyle'}, scalar @colours );
	} # end if
	$setup_rate = $Press->specification( 'MakeReady Overs Rate', scalar @colours ) if ! $setup_rate;

	my $setup_overs;
 	if ( $$specs{'OverrideSetup'.$qty_index} eq 'Y' ) {
		$setup_overs = $$specs{'OverSetup'.$qty_index};
	} elsif ( $setup_rate ) {
		$setup_overs = int( $setup_rate * scalar @colours );
 	} else {
		$setup_overs = $Press->specification( 'MakeReady Overs ' . $$Imposition{'runstyle'}, scalar @colours );
		$setup_overs = $Press->specification( 'MakeReady Overs', scalar @colours ) if ! $setup_overs;
 	} # end if

	my $run_overs;
	my $over_rate = 0;
	if ( $$specs{'OverrideRun'.$qty_index} eq 'Y' ) {
		$run_overs = $$specs{'OverRun'.$qty_index};
	} else {
		# Should include bindery overs, but not setups, because the setup overs do the same job as the Run Overs
		$over_rate = $Press->specification( 'Press Run Overs', $net_sheets );
		$price{'Overs Rate'} = $over_rate;
		if ( ( $$specs{'txtSignatureType'} eq 'Cover Pages' ) and ( $_ = $Press->specification( 'Covers Overs Percentage' ) ) ) {
			$over_rate *= ( 1 + $_ / 100 );
		} # end if
		$run_overs = $net_sheets * $over_rate;
	} # end if

	my $fm_overs = 0;
	if ( $$specs{'ScreenType'} eq 'FM' ) {
		$fm_overs = $Press->specification( 'FM Screening Additional Overs', undef );
		$setup_overs += $fm_overs;
	} # end if
	my $additional_overs = 0;
	if ( $$specs{'txtPlateChangeQuantity'.$qty_index} ) {
		$additional_overs = ( $$specs{'txtPlateChangeQuantity'.$qty_index} * $Press->specification('Additional Plate Overs') );
		my $minimum = $Press->specification('Additional Plate Overs Minimum');
		$additional_overs = $minimum if $minimum > $additional_overs;
	} # end if
	my $overs = $additional_overs;
	if ( $Press->specification('Overs') ne 'All' ) {
		$overs += ceil( ($setup_overs > $run_overs) ? $setup_overs : $run_overs );
	} else {
		$overs += ceil( $setup_overs + $run_overs );
	} # end if
	$overs *= $Paper->parts() if $Paper->parts();
	$overs = $min_overs if $overs < $min_overs;

	my $impressions = $net_sheets + $overs;
	$impressions *= $$project{print_sides} if (sets::isin($$Imposition{runstyle},['Sheet Work','Work & Turn','Work & Tumble'] ));

	my $max_impression_quantity = $Press->specification('Maximum Impression Quantity', $$Paper{calliper} );
	if ( $max_impression_quantity and ($max_impression_quantity < $impressions ) ) {
		$openprint::log->debug("Next cuz of maximum impression quantity $max_impression_quantity : $impressions" ) if $debug;
		return \%price;
	} # end if
	$$specs{'hdnImpressionQuantity'.$qty_index} = $impressions;

	my $std_speed = $Press->Specification('Run Speed' );
	my $run_speed;
	if ( $$std_speed{'units'} eq 'Calliper' ) {
		$run_speed = $Press->specification('Run Speed', $Paper->calliper() );
	} else {
		$run_speed = $Press->specification('Run Speed', $Paper->gsm() );
	} # end if

    my $speed_mod = $Press->specification('Press Additional Run Speed',$Paper->calliper() );
#$openprint::log->warn("Press ".$Press->strid()." Calliper:". $Imposition->paper()->calliper()." STD: ($run_speed) RUN ($speed_mod),  std/run: " . ( $speed_mod ? $run_speed/$speed_mod : $run_speed ) ) if $debug or 1;
    $run_speed = $speed_mod if $speed_mod;

	my %folding_results;

# Has to be NEED because they always leave folding out, and it chooses dumb impositions
	if ( $$project{'NeedFolding'} ) {
		my $time = gettimeofday();
		if ( $$Imposition{'folding_results'} ) {
			%folding_results = %{$$Imposition{'folding_results'}};
		} else {
			%folding_results = openprint::Estimating::Folding::signature_calc( $Project, $service_index, $specs, $$project{'FoldingSpecs'}, $qty_index, $Paper, $Imposition, @$project{'UVCoatingSpecs','AqueousSpecs'} );
			#$$Imposition{'folding_results'} = \%folding_results;
		} # end if

		delete $$Imposition{'Folder'};
		if ( ( $folding_results{'Status'} eq 'uncalculated' ) or ! $folding_results{'Equipment'} ) {
# do not want an invalid fold style to win out unless there are no other valid signatures.
			$price{'Folding Breakdown'} .= sprintf('Unable to fold<br/>');
			$price{'Comparison Cost'} += 10000000; 
			if ( $$project{'FoldingSpecs'}{"chkOverrideEquipment-$$specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$project{'FoldingSpecs'}{"ddmEquipment-$$specs{'SignatureIndex'}-$qty_index"} = '';
			} # end if
		} else {
			if ( $folding_results{'Equipment'}->id() == $Press->id() ) {
#$openprint::log->debug("Runspeed: $folding_results{'RunSpeed'}");
				$run_speed = $folding_results{'RunSpeed'} if $folding_results{'RunSpeed'};
			} # end if
			$$Imposition{'Folder'} = $folding_results{'Equipment'};

			foreach my $k ( keys %{$folding_results{'Folds'}} ) {
				my ( $fold_type, $imposition ) = $k =~ /(.*)-(\d+)out$/;
				my $fold_qty = 0;
				foreach my $Fold ( @{$folding_results{'Folds'}{$k}} ) {
					$fold_qty += $Fold->Imposition()->quantity();
				} # end foreach
				$price{'Folding Breakdown'} .= sprintf('Folding %d %s (%d out) %d/hr Price: $%.2f on %s', $fold_qty, $folding_results{'Folds'}{$k}[0]->name(), $imposition, @folding_results{'RunSpeed','Price'}, $folding_results{'Equipment'}->name() ) .'<br/>' if $folding_results{'Equipment'};
			} # end foreach
			if ( $$project{'FoldingSpecs'}{"chkOverrideEquipment-$$specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$project{'FoldingSpecs'}{"ddmEquipment-$$specs{'SignatureIndex'}-$qty_index"} = $folding_results{'Equipment'}->id();
			} # end if
		} # end if
		if ( 0 and tv_interval( [$time])*1000 > 10 ) {
			$openprint::log->debug("Folding Calculation time: " . ( sprintf('%.4f', tv_interval( [$time])*1000) ) .' usecs' );
			$Imposition->display('Slow Folding');
			$openprint::log->debug( $folding_results{'Breakdown'} );
		} # end if
		$price{'FoldingImposition'} = $folding_results{'Imposition'};
		$$Imposition{'FoldingImposition'} = $folding_results{'Imposition'};
#$openprint::log->debug("FOlding IMPOSITION $folding_results{'Imposition'}");

		$price{'Comparison Cost'} += $folding_results{'Price'};
#$price{'Folding Breakdown'} .= 'FOlding comparison price: ' . $price{'Comparison Cost'}.'<br/>';
	} else {
		$price{'Folding Breakdown'} .= 'Folding not needed<br/>';
	} # end if
	if ( $$services{'SpinePaste'} ) {
		if ( $Imposition->pages() < $$specs{'txtUnspecifiedPageQuantity'.$qty_index} ) {
			$price{'SpinePaste Breakdown'} .= 'SpinePaste error: Must be 1 signature<br/>';
			$price{'Comparison Cost'} += 1000000; # Can't SP this on
			$price{'SpinePaste Cost'} = 1000000;
			return \%price;
		} # end if
#my $starttime = gettimeofday();

		my $results = openprint::Estimating::SpinePaste::signature_calc( $Project, $service_index, $Imposition, $$project{'SpinePasteSpecs'}, $qty_index, \%folding_results );
		if ( $$results{'Status'} eq 'uncalculated' ) {
			$price{'SpinePaste Breakdown'} .= "SpinePaste error: $$results{'alert'}<br/>";
			$price{'Comparison Cost'} += 1000000; # Can't SP this on
				$price{'SpinePaste Cost'} = 1000000;
		} else {
			$price{'SpinePaste Breakdown'} .= sprintf('SpinePaste MR: %dminutes RS: %d/hr Price: $%.2f<br/>%s<br/>', @$results{'MakeReadyTime','RunSpeed','Price','alert'} );
			$price{'SpinePaste Cost'} = $$results{'Price'};
			$price{'Comparison Cost'} += $$results{'Price'};
#$openprint::log->debug( 'Stitching Calc: ' . sprintf('%.4f', tv_interval( [$starttime])*1000) );
			if ( $$results{'Equipment'}->id() == $Press->id() ) {
				$run_speed = $$results{'RunSpeed'} if $$results{'RunSpeed'} < $run_speed;
			} # end if
		} # end if
	} # end if

	my %diecutting_results;
	if ( $$project{'HasDieCutting'} and $$project{'NeedDieCutting'} ) {
		%diecutting_results = openprint::Estimating::DieCutting::signature_calc( $Project, $service_index, $specs, $$project{'DieCuttingSpecs'}, $qty_index, $Imposition );
		if ( $diecutting_results{'Status'} eq 'uncalculated' ) {
			$price{'DieCutting Breakdown'} .= "DieCutting error: $diecutting_results{'alert'} $diecutting_results{alert} <br/>";
			$price{'Comparison Cost'} += 1000000; 
		} else {
			$price{'DieCutting Breakdown'} .= sprintf('DieCutting Price: $%.2f on %s<br/>', $diecutting_results{'Price'}{'Total'}, $diecutting_results{'Equipment'} ? $diecutting_results{'Equipment'}->name() : '' );
			$price{'Comparison Cost'} += $diecutting_results{'Price'}{'Total'};
		} # end if
	} # end if

	my %numbering_results;
	if ( $$project{'HasNumbering'} ) {
		%numbering_results = openprint::Estimating::Numbering::signature_calc( $Project, @$project{'HasNumbering','NumberingSpecs'}, $specs, $qty_index, $Imposition );
#foreach my $k ( keys %scoring_results ) {
#$openprint::log->debug("Scoring: $k => $scoring_results{$k}");
#}
		if ( $numbering_results{'Status'} eq 'uncalculated' ) {
			$price{'Numbering Breakdown'} .= "Numbering error: $numbering_results{'alert'} $numbering_results{Breakdown}".'<br/>';
			$price{'Comparison Cost'} += 1000000; 
		} else {
			$price{'Numbering Breakdown'} .= sprintf('Numbering Price: %dout $%.2f on %s<br/>', $numbering_results{'Imposition'}->imposition(), $numbering_results{'Total'}, $numbering_results{'Equipment'} ? $numbering_results{'Equipment'}->name() : '' );
			$price{'Comparison Cost'} += $numbering_results{'Total'};
		} # end if
	} # end if

	my %scoring_results;
	if ( $$project{'HasScoring'} and $$project{'NeedScoring'} ) {
		%scoring_results = openprint::Estimating::Scoring::signature_calc( $Project, @$project{'HasScoring','ScoringSpecs'}, $service_index, $specs, $qty_index, $Imposition );
#foreach my $k ( keys %scoring_results ) {
#$openprint::log->debug("Scoring: $k => $scoring_results{$k}");
#}
		if ( $scoring_results{'Status'} eq 'uncalculated' ) {
			$price{'Scoring Breakdown'} .= "Scoring error: $scoring_results{'alert'} $$project{'ScoringSpecs'}{alert} " . $$project{'ScoringSpecs'}{'hdnBreakdown'.$qty_index} . '<br/>';
			$price{'Comparison Cost'} += 1000000; 
		} elsif ( $scoring_results{'Imposition'} ) {
			$price{'Scoring Breakdown'} .= sprintf('Scoring Price: %dout $%.2f on %s<br/>', $scoring_results{'Imposition'}->imposition(), $scoring_results{'Price'}, $scoring_results{'Equipment'} ? $scoring_results{'Equipment'}->name() : '' );
			$price{'Comparison Cost'} += $scoring_results{'Price'};
			if ( $scoring_results{'Equipment'} and ( $scoring_results{'Equipment'}->id() == $Press->id() ) ) {
				if ( $scoring_results{'Runspeed'} =~ /(.*)\%/ ) {
					$run_speed *= (1+$1/100);
				} else {
					$run_speed = $scoring_results{'Runspeed'} if $run_speed > $scoring_results{'Runspeed'};
				} # end if
			} # end if
			$scoring_results{'Overs'} = ceil( $scoring_results{'Overs'} / ( $Imposition->imposition()/$scoring_results{'Imposition'}->imposition() ) ) if $scoring_results{'Imposition'}->imposition();
		} # end if
	} # end if
	if ( $$project{'HasPerforating'} ) {
		my %perforating_results = openprint::Estimating::Perforating::signature_calc( $Project, @$project{'HasPerforating','PerforatingSpecs'}, $service_index, $specs, $qty_index, $Imposition );
		if ( $perforating_results{'Status'} eq 'uncalculated' ) {
			$price{'Perforating Breakdown'} .= "Perforating error: $perforating_results{'alert'} $$project{'PerforatingSpecs'}{alert} " . $perforating_results{'Breakdown'} . '<br/>';
			$price{'Comparison Cost'} += 1000000; 
		} else {
			$price{'Perforating Breakdown'} .= sprintf('Perforating Price: %.2f speed: %s<br/>', @perforating_results{'Price','Runspeed'} );
			$price{'Comparison Cost'} += $perforating_results{'Price'};
			if ( $perforating_results{'Equipment'} and ($perforating_results{'Equipment'}->id() == $Press->id()) ) {
				if ( $perforating_results{'Runspeed'} =~ /(.*)\%/ ) {
					$run_speed *= (1+$1/100);
				} else {
					$run_speed = $perforating_results{'Runspeed'} if $run_speed > $perforating_results{'Runspeed'};
				} # end if
			} # end if
		} # end if
	} # end if
	my %uv_results;
	if ( $$project{'HasUVCoating'} ) {
		%uv_results = openprint::Estimating::UVCoating::signature_calc( $Project, @$project{'HasUVCoating','UVCoatingSpecs'}, $service_index, $specs, $qty_index, $Imposition, {} );
		if ( $uv_results{'Status'} eq 'uncalculated' ) {
			$price{'UVCoating Breakdown'} .= "UV error: $uv_results{'alert'} $$project{'UVCoatingSpecs'}{alert} " . $$project{'UVCoatingSpecs'}{'hdnBreakdown'.$qty_index} . '<br/>';
			$price{'Comparison Cost'} += 1000000; 
		} elsif ( $uv_results{'Equipment'} ) {
			$price{'UVCoating Breakdown'} = sprintf('UVCoating Price: $%.2f on %s<br/>', $uv_results{'Total'}, $uv_results{'Equipment'}->name() );
			$price{'Comparison Cost'} += $uv_results{'Total'};
		} # end if
	} # end if UVCoating
# Now add in cutting costs to the comparison
	if ( $$project{'HasCutting'} ) {
		if ( ($Paper->type() ne 'Roll') and ($Paper->start_width() != $Paper->width() or $Paper->start_height() != $Paper->height() ) ) {
#my $time = gettimeofday();
			my %cutting_results = openprint::Estimating::Cutting::signature_calc_stock_cutting( $Project, undef, $specs, $$project{'CuttingSpecs'}, $qty_index, $Paper, $Imposition );
			$price{'Cutting Breakdown'} .= "Stock Cutting Price: \$$cutting_results{'Price'} $cutting_results{'alert'}<br/>";
			$price{'Comparison Cost'} += $cutting_results{'Price'};
#$openprint::log->debug("Elapsed stock cutting time:" . ( sprintf('%.4f', tv_interval( [$time])*1000) ) .' usecs' );
		} # end if

#my $time = gettimeofday();
		my %cutting_results = openprint::Estimating::Cutting::signature_calc( $Project, undef, $specs, $$project{'CuttingSpecs'}, $qty_index, $Paper, $Imposition );
#foreach my $k ( keys %cutting_results ) {
#$openprint::log->debug("Cutting: $k => $cutting_results{$k}");
#}
		
#$openprint::log->debug("Elapsed cutting time:" . ( sprintf('%.4f', tv_interval( [$time])*1000) ) .' usecs' );
		if ( $cutting_results{'Status'} eq 'uncalculated' ) {
			$price{'Cutting Breakdown'} .= "Cutting error: $cutting_results{'alert'}<br/>";
		} else {
			$price{'Cutting Breakdown'} .= sprintf('Cutting Price: $%.2f',$cutting_results{'Price'} );
			$price{'Cutting Breakdown'} .= ' on '. $cutting_results{'Equipment'}->name() if $cutting_results{'Equipment'};
			$price{'Cutting Breakdown'} .= '<br/>';

#$price{'Cutting Breakdown'} .= $$project{'CuttingSpecs'}{'hdnBreakdown'.$qty_index}.'<br/>';
			$price{'Comparison Cost'} += $cutting_results{'Price'};
		} # end if
		$price{'Cutting Overs'} = $cutting_results{'Overs'};
	} # end if

	$price{'Run Speed'} = $run_speed;

	# Now we know the bindery overs
	my $bindery_overs = sets::max( $folding_results{'MakeReadyOvers'} + $folding_results{'RunOvers'}, $scoring_results{'Overs'}, $uv_results{'Overs'}, $diecutting_results{'Overs'}, $price{'Cutting Overs'} );
	$bindery_overs *= $Paper->parts() if $Paper->parts();
	$overs += ( $bindery_overs - $overs ) if $bindery_overs > $overs;
	$overs = $min_overs if $overs < $min_overs;

	my $gross_sheets = $net_sheets + $overs;
	$impressions = $gross_sheets;
	$impressions *= $$project{print_sides} if (sets::isin($$Imposition{runstyle},['Sheet Work','Work & Turn','Work & Tumble'] ));

	my $min_impression_quantity = $Press->specification('Minimum Impression Quantity', $$Paper{calliper} );
	if ( $min_impression_quantity and ( $min_impression_quantity > $impressions ) ) {
		$openprint::log->debug("Next cuz of minimum impression quantity $min_impression_quantity: $impressions" ) if $debug;
		return \%price;
	} # end if

	$price{'Ink Price'} = 0;

	# We copy these so that we can add to them while considering side two, and for future sigs?
	my $plate_count = 0;
	my $non_process_colours = 0;
	my ($plate_type,$plate_size,$max_impressions) = (
			$Press->specification('Plate Type'),
			$Press->specification('Plate Size'),
			$Press->specification('Maximum Plate Impressions'),
			);
	$max_impressions = int($max_impressions);
	$max_impressions = 250000 if ! $max_impressions;
	my $plate_runs = ceil($impressions/$max_impressions);
	my $plate_id = $plate_size . '-' . $plate_type . 'Plate';
	my %plate_setup = ( 'Plate Type', $plate_type, 'Plate ID', $plate_id, 'Plate Runs', $plate_runs,);
	
	my %mixed_colours = %{$$project{'mixed_colours'}};
	my %washed_colours = %{$$project{'washed_colours'}};
	my @left_over_colours;
	foreach my $real_colour ( @colours ) {
		my $colour;
		if ( ( $real_colour =~ /UV/ ) or ( $real_colour =~ /Aqueous/ ) ) {
			push @left_over_colours, $real_colour;
			next;
		} # end if

		$price{'Ink breakdown'} .= $real_colour;

		if ( $real_colour =~ /Varnish/ ) {
			#$price{'Press Washes'} += 1;
			$colour = $real_colour;
			if ( sets::isin( $Imposition->runstyle(), ['Work & Turn','Work & Tumble'] ) ) {
				if ( ( $real_colour =~ /Overall/ ) and ! ( sets::isin( $real_colour, $$project{'side_one_colours'} ) and sets::isin( $real_colour, $$project{'side_two_colours'} ) ) ) {
					$real_colour =~ s/Overall/Spot/;
				} # end if
			} # end if
			$colour =~ s/ ?Overall ?//;
			$colour =~ s/ ?Spot ?//;
			if ( $real_colour =~ /Spot/ ) {
				# Add Blanket Cut
				my %BlanketCut = openprint::service::get_price_object( $real_colour.' BlanketCut', undef, $Press );
				%BlanketCut = openprint::service::get_price_object( 'BlanketCut', undef, $Press ) if ! %BlanketCut;
				if ( %BlanketCut ) {
					$price{'Ink breakdown'} .= sprintf(' Blanket: $%.2f', $BlanketCut{'Price'} );
					$price{'Ink Price'} += $BlanketCut{'Price'};
				} # end if
			} # end if

		} elsif ( $real_colour =~ /(\w*) Spot Colour/ ) {
			$colour = $1.'Ink';
		} elsif ( $real_colour =~ /PMS/i ) {
			$colour = 'PMSInk';
		} elsif ( $real_colour =~ /Metallic/i ) {
			$colour = 'MetallicInk';
		} else { 
			$colour = $real_colour . 'Ink';
		} # end if
		if ( $real_colour =~ /Varnish/ and $real_colour =~ /Overall/ and $washed_colours{$real_colour.'-'.$Press->strid().'-'.$qty_index} ) {
		} else {
			$plate_count += 1;
		} # end if

# Each Ink/Coating has MakeReady, Mix, Material, Service
		if ( ! ( $real_colour =~ /Varnish/ and $washed_colours{$real_colour.'-'.$Press->strid().'-'.$qty_index} ) ) {
			my %InkMakeReady = openprint::service::get_price_object( $real_colour.' MakeReady', undef, $Press );
			if ( %InkMakeReady ) {
				$price{'Ink breakdown'} .= sprintf(' MR: %.2f', $InkMakeReady{'Price'} );
				$price{'Ink Price'} += $InkMakeReady{'Price'};
			} # end if
		} # end if

		my %InkService = openprint::service::get_price_object( $real_colour, $qty, $Press );
		if ( %InkService ) {
			if ( lc $InkService{'units'} eq 'per m' ) {
				$InkService{'Total'} = $InkService{'Price'} * $qty/1000;
			} # end if
			$price{'Ink breakdown'} .= sprintf(' Run: $%.2f%s = $%.2f', @InkService{'Price','units','Total'} );
			$price{'Ink Price'} += $InkService{'Total'};
		} # end if

		my %ink_price;
		my $InkMaterial;

		# Special colours is a hash of all the defined colours in the db
		if ( $$project{'special_colours'}{$real_colour} ) {

			if ( $$project{'special_colours'}{$real_colour}{service_id} and ! $mixed_colours{$real_colour} ) {
				my $Service = new openprint::Service( $$project{'special_colours'}{$real_colour}{service_id} );
				my %mix_price = $Service->get_price(undef,$Press);
				$price{'Ink Mix Charge'} += $mix_price{'Price'};
				$mixed_colours{$real_colour} = 1;
			} # end if

# Washed_colours contains each colour used in the other signatures
			if ( ! $washed_colours{$real_colour.'-'.$Press->strid().'-'.$qty_index} ) {
				# Perfecting uses another set of units, but the second side won't add because of the colour already being washed
				if ( sets::isin( $$Imposition{runstyle}, ['Web','Perfecting'] ) and sets::isin( $real_colour, $$project{'side_one_colours'} ) and sets::isin( $real_colour, $$project{'side_two_colours'} ) ) {
					$price{'Press Washes'} += $$project{'special_colours'}{$real_colour}{washups};
				} # end if
				$price{'Press Washes'} += $$project{'special_colours'}{$real_colour}{washups};
				$washed_colours{$real_colour.'-'.$Press->strid().'-'.$qty_index} = 1;
			} # end if
#
#$openprint::log->debug("Special Colour: $real_colour $$inkCoverage{$real_colour}");
			$InkMaterial = new openprint::Material( $$project{'special_colours'}{$real_colour}->{material_id} );
			%ink_price = $InkMaterial->get_price( undef, $Press );
		} elsif ( ! sets::isin( $real_colour, ['Cyan','Magenta','Yellow','Black','Cyan Spot Colour','Yellow Spot Colour','Magenta Spot Colour','Black Spot Colour'] ) ) {
			$non_process_colours += 1;
#$openprint::log->debug("Colour: $real_colour : " .  $washed_colours{$real_colour.'-'.$Press->strid().'-'.$qty_index} );
			# PMS or Varnish ?
			if ( ( ! ($real_colour =~ /Varnish/) ) and ! $mixed_colours{$real_colour} ) {
			#if ( ! $mixed_colours{$real_colour} ) {
				my %mix_price = openprint::service::get_price_object( 'PMSInkMix',undef,$Press);
				$price{'Ink Mix Charge'} += $mix_price{'Price'};
				$mixed_colours{$real_colour} = 1;
			} # end if

			if ( ! $washed_colours{$real_colour.'-'.$Press->strid().'-'.$qty_index} ) {
				if ( sets::isin( $$Imposition{runstyle}, ['Web','Perfecting'] ) and sets::isin( $real_colour, $$project{'side_one_colours'} ) and sets::isin( $real_colour, $$project{'side_two_colours'} ) ) {
					$price{'Press Washes'} += 1;
				} # end if
				$price{'Press Washes'} += 1;
				$washed_colours{$real_colour.'-'.$Press->strid().'-'.$qty_index} = 1;
			} # end if
		} # end if
		if ( ! %ink_price ) {
#$openprint::log->debug("Getting price for $colour");
			if ( my @Materials = openprint::Material::find('name'=>$colour) ) {
#$openprint::log->debug("Got price for $colour");
				$InkMaterial = $Materials[0];
				%ink_price = $Materials[0]->get_price( undef, $Press );
			} # end if
		} # end if
		if ( ! ( $InkMaterial and %ink_price ) ) {
			$price{'Ink breakdown'} .= '<br/>';
			next;
		} # end if

		my $area = $Imposition->object_area() * $impressions * ($$project{'inkCoverage'}{$real_colour}/100);
		$area /= 2 if $Imposition->runstyle() eq 'Sheet Work' and $$specs{'sides_the_same'} ne 'Y';
		my $grade = $Imposition->Paper()->grade();
		$grade = 4 if ! $grade;

		if ( lc $ink_price{'units'} eq 'per kg' ) {
			if ( sets::isin( $real_colour, $$project{'side_one_colours'} ) and sets::isin( $real_colour, $$project{'side_two_colours'} ) ) {
				$area /= 2;
			} # end if
			my $coverage = $InkMaterial->specification('Coverage', $grade);
			my $qty = sprintf('%.2f', $area/$coverage ) if $coverage;
			my %ink_price = $InkMaterial->get_price( $qty, $Press );
			$price{'Ink Price'} += $ink_price{'Price'} * $qty;
			$price{'Ink breakdown'} .= sprintf(' mileage: %d, %.2f * $%s%s=$%.2f', $coverage,$qty, $ink_price{'Price'},$ink_price{'units'},$ink_price{'Price'} * $qty);
		} elsif ( lc $ink_price{'units'} eq 'per square foot' ) {
			$area /= 144;
			my $p = $ink_price{'Price'} * $area;
			$price{'Ink Price'} += $p;
			$price{'Ink breakdown'} .= sprintf(' Grade: %d, %.2f sq feet * $%s%s = $%.2f', $grade, $area, @ink_price{'Price','units'}, $p );
		} elsif ( lc $ink_price{'units'} eq 'per unit' ) {
			if ( sets::isin( $real_colour, $$project{'side_one_colours'} ) and sets::isin( $real_colour, $$project{'side_two_colours'} ) ) {
				$area /= 2;
			} # end if
			my $sheets_per_ink_unit = 750000;
			my $p = $ink_price{'Price'} * ($area/$sheets_per_ink_unit) / $$project{'print_sides'};
			$price{'Ink Price'} += $p;
			$price{'Ink breakdown'} .= sprintf(' %.2f sq feet * $%s%s / %d sheets per unit = $%.2f', $area, @ink_price{'Price','units'}, $sheets_per_ink_unit, $p );
		} elsif ( lc $ink_price{'units'} eq 'per square inch' ) {
			my $p = $ink_price{'Price'} * $area;
			$price{'Ink Price'} += $p;
			$price{'Ink breakdown'} .= sprintf(' Grade: %d, %d sq inches * $%s%s = $%.2f', $grade, $area, @ink_price{'Price','units'}, $p );
		} elsif ( lc $ink_price{'units'} eq 'per m' ) {
			$price{'Ink Price'} += $ink_price{'Price'} * $impressions/1000;
			$price{'Ink breakdown'} .= sprintf( ' %d * $%.2f%s = %.2f', $impressions, @ink_price{'Price','units'}, $ink_price{'Price'} * $impressions/1000 );
		} else {
#$run_price = 0;
			$openprint::log->error("Unknown units for $colour: $ink_price{'units'}" . $Press->strid() );
		} # end if
		$price{'Ink breakdown'} .= '<br/>';
	} # end foreach colour/coating

	$plate_count *= $plate_runs;
	$plate_count += $$specs{'txtPlateChangeQuantity'.$qty_index};
	my $blanks_needed;
	if ( $Press->specification( 'Require Blank Plates' ) eq 'Y' ) {
		$blanks_needed = ($Press->specification('Number of Colours') - @colours) - $$PlateCounts{'Blank'.$plate_id};
		$plate_setup{'Blank Plates'} = $blanks_needed;
	} elsif ( $non_process_colours and ( $Press->specification( 'Require Blank Plates' ) eq 'When Non-Process' ) ) {
		$blanks_needed = ($Press->specification('Number of Colours') - @colours) - $$PlateCounts{'Blank'.$plate_id};
		$plate_setup{'Blank Plates'} = $blanks_needed;
	} # end if
	$plate_setup{'Plate Count'} = $plate_count;
#$Imposition->display("Plate Count $plate_count");

#$price{'Press Washes'} += $varnish_price{'Press Washes'};
	if ( $price{'Press Washes'} ) {
		$price{'Press Wash Price'} = openprint::service::get_price( 'WashUp', undef, $Press );
		$price{'Press Wash Total'} = $price{'Press Washes'} * $price{'Press Wash Price'};
	} # end if

	$price{'Plate Costs'} = \%plate_setup;
	$price{'rdbPlates'} = $plate_setup{'Plate Type'};
	$price{'Plate Total'} = 0;

	my $press_setup = 0;
	if ( $$Imposition{runstyle} eq 'Sheet Work' ) {
		if ( @{$$project{'side_one_colours'}} and @{$$project{'side_two_colours'}} ) {
			$_ = press_setup_cost( $Press, $$specs{'txtPlateChangeQuantity'.$qty_index}/2, $plate_setup{'Plate Runs'}, $$project{'side_one_colours'}, $$Paper{calliper}, $specs, $qty_index, $service_index, $Imposition );
			$press_setup += $_->{'Total'};
			$price{'Setup Breakdown'} .= sprintf('%d units * $%.2f%s = $%.2f<br/>', @$_{'Unit Count','Price','units','Total'} );
			$price{'Plate Total'} += $_->{'Plate Total'};
			$_ = press_setup_cost( $Press, $$specs{'txtPlateChangeQuantity'.$qty_index}/2, $plate_setup{'Plate Runs'}, $$project{'side_two_colours'}, $$Paper{calliper}, $specs, $qty_index, $service_index, $Imposition );
			$press_setup += $_->{'Total'};
			$price{'Setup Breakdown'} .= sprintf('%d units * $%.2f%s = $%.2f<br/>', @$_{'Unit Count','Price','units','Total'} );
			$price{'Plate Total'} += $_->{'Plate Total'};
			$price{'Plate Setup Price'} = $_->{'Plate Price'};
			$price{'Plate Setup Count'} = $_->{'Plate Count'};
			$price{'Plate Setup Units'} = $_->{'Plate Units'};
		} elsif ( @{$$project{'side_one_colours'}} ) {
			$_ = press_setup_cost( $Press, $$specs{'txtPlateChangeQuantity'.$qty_index}, $plate_setup{'Plate Runs'}, $$project{'side_one_colours'}, $$Paper{calliper}, $specs, $qty_index, $service_index, $Imposition );
			$press_setup += $_->{'Total'};
			$price{'Setup Breakdown'} .= sprintf('%d units * $%.2f%s = $%.2f<br/>', @$_{'Unit Count','Price','units','Total'} );
			$price{'Plate Total'} += $_->{'Plate Total'};
			$price{'Plate Setup Price'} = $_->{'Plate Price'};
			$price{'Plate Setup Count'} = $_->{'Plate Count'};
			$price{'Plate Setup Units'} = $_->{'Plate Units'};
		} elsif ( @{$$project{'side_two_colours'}} ) {
			$_ = press_setup_cost( $Press, $$specs{'txtPlateChangeQuantity'.$qty_index}, $plate_setup{'Plate Runs'}, $$project{'side_two_colours'}, $$Paper{calliper}, $specs, $qty_index, $service_index, $Imposition );
			$press_setup += $_->{'Total'};
			$price{'Setup Breakdown'} .= sprintf('%d units * $%.2f%s = $%.2f<br/>', @$_{'Unit Count','Price','units','Total'} );
			$price{'Plate Total'} += $_->{'Plate Total'};
			$price{'Plate Setup Price'} = $_->{'Plate Price'};
			$price{'Plate Setup Count'} = $_->{'Plate Count'};
			$price{'Plate Setup Units'} = $_->{'Plate Units'};
		} # end if
	} elsif ( sets::isin( $$Imposition{runstyle}, ['Web','Perfecting'] ) ) {
		$_ = press_setup_cost( $Press, $$specs{'txtPlateChangeQuantity'.$qty_index}, $plate_setup{'Plate Runs'}, \@colours, $$Paper{calliper}, $specs, $qty_index, $service_index, $Imposition );
		$press_setup += $_->{'Total'};
		$price{'Setup Breakdown'} .= sprintf('%d units * $%.2f%s = $%.2f<br/>', @$_{'Unit Count','Price','units','Total'} );
		$price{'Plate Total'} += $_->{'Plate Total'};
		$price{'Plate Setup Price'} = $_->{'Plate Price'};
		$price{'Plate Setup Count'} = $_->{'Plate Count'};
			$price{'Plate Setup Units'} = $_->{'Plate Units'};
	} else {
		$_ = press_setup_cost( $Press, $$specs{'txtPlateChangeQuantity'.$qty_index}, $plate_setup{'Plate Runs'}, \@colours, $$Paper{calliper}, $specs, $qty_index, $service_index, $Imposition );
		$press_setup += $_->{'Total'};
		$price{'Setup Breakdown'} .= sprintf('%d units * $%.2f%s = $%.2f<br/>', @$_{'Unit Count','Price','units','Total'} );
		$price{'Plate Total'} += $_->{'Plate Total'};
		$price{'Plate Setup Price'} = $_->{'Plate Price'};
		$price{'Plate Setup Count'} = $_->{'Plate Count'};
		$price{'Plate Setup Units'} = $_->{'Plate Units'};
	} # end if
	my $setup_cost = $press_setup + $price{'WorkTurn Dry Charge'} + $price{'Plate Total'} + $price{'Ink Mix Charge'} + $price{'Press Wash Total'};

	# Recalculate Overs, etc using Plate Count now
	if ( $$project{'print_sides'} == 1 ) {
		$setup_rate = $Press->specification( 'MakeReady Overs Rate One Side', $plate_setup{'Plate Count'} );
	} else {
		$setup_rate = $Press->specification( 'MakeReady Overs Rate '.$$Imposition{'runstyle'}, $plate_setup{'Plate Count'} );
	} # end if
	$setup_rate = $Press->specification( 'MakeReady Overs Rate', $plate_setup{'Plate Count'} ) if ! $setup_rate;
	if ( $$specs{'OverrideSetup'.$qty_index} eq 'Y' ) {
		$setup_overs = $$specs{'OverSetup'.$qty_index};
	} elsif ( $setup_rate ) {
		$setup_overs = int( $setup_rate * $plate_setup{'Plate Count'} );
 	} else {
		$setup_overs = $Press->specification( 'MakeReady Overs ' . $$Imposition{'runstyle'}, $plate_setup{'Plate Count'} );
		$setup_overs = $Press->specification( 'MakeReady Overs', $plate_setup{'Plate Count'} ) if ! $setup_overs;
 	} # end if
	$setup_overs += $fm_overs;
	$setup_overs *= $Paper->parts() if $Paper->parts();

	if ( $$specs{'OverrideRun'.$qty_index} eq 'Y' ) {
		$run_overs = $$specs{'OverRun'.$qty_index};
	} else {
		$run_overs = ceil( $net_sheets * $over_rate );
		$run_overs *= $Paper->parts() if $Paper->parts();
	} # end if

	my $total_overs = $additional_overs;

	if ( $Press->specification('Overs') ne 'All' ) {
		$total_overs = ceil( ( $setup_overs > $run_overs ) ? $setup_overs : $run_overs );
	} else {
		$total_overs = ceil( $run_overs + $setup_overs );
	} # end if
	$total_overs += $bindery_overs - $total_overs if $bindery_overs > $total_overs;

	$min_overs = $Press->specification( 'Overs Minimum', $plate_setup{'Plate Count'} );
	$total_overs *= $Paper->parts() if $Paper->parts();
	$total_overs = $min_overs if $total_overs < $min_overs;

	my $gross_sheets = $net_sheets + $total_overs;
	$impressions = $gross_sheets;
	$impressions *= $$project{print_sides} if (sets::isin($$Imposition{runstyle},['Sheet Work','Work & Turn','Work & Tumble'] ));
	my $weight = ceil( $gross_sheets * $Paper->sheet_weight() );

	my %sheet_qty = (
			'Impressions'				=>	$impressions, 
			'Gross Sheet Count'			=>	$gross_sheets, 
			'Net Sheet Count'			=>	$net_sheets,
			'Setup Overs'				=>	$setup_overs,
			'Run Overs'					=>	$run_overs,
			'Additional Plate Overs'	=>	$additional_overs,
			'Total Overs'				=>	$total_overs,
			'Weight'					=>	$weight,
			'FM Overs'					=>	$fm_overs,
			'FoldingMakeReadyOvers'		=>	$folding_results{'MakeReadyOvers'},
			'FoldingRunOvers'			=>	$folding_results{'RunOvers'},
			'ScoringOvers'				=>	$scoring_results{'Overs'},
			'DieCuttingOvers'			=>	$diecutting_results{'Overs'},
			'UVOvers'					=>	$uv_results{'Overs'},
			'BinderyOvers'				=>	$bindery_overs,
			'CuttingOvers'				=>	$price{'Cutting Overs'},
			);
	$price{'Stock Quantity'} = \%sheet_qty;
	$price{'Gross Sheet Count'} = $sheet_qty{'Gross Sheet Count'};
	$price{'Net Sheet Count'} = $sheet_qty{'Net Sheet Count'};
	$price{'Stock Weight'} = $sheet_qty{'Weight'};
	$price{'Stock Qty'} = $Paper->type() eq 'Sheet' ? $sheet_qty{'Gross Sheet Count'} : $sheet_qty{'Weight'};

	$$specs{"txtPressSheetQty$qty_index"} = $gross_sheets;
	if ( $Press->specification('Charge for setup overs') eq 'N' ) {
		$impressions -= $setup_overs;
	} # end if
	$$specs{'hdnImpressionQuantity'.$qty_index} = $impressions;
	$$specs{'ddmPress'.$qty_index} = $Press->strid();

	if ( $$project{'HasAqueous'} ) {
		my %aq_results = openprint::Estimating::Aqueous::signature_calc( $Project, @$project{'HasAqueous','AqueousSpecs'}, $service_index, $specs, $qty_index, $Imposition );
	#$price{'Aqueous Breakdown'} .= $$project{'AqueousSpecs'}{'hdnBreakdown'.$qty_index};
		if ( $aq_results{'Status'} eq 'uncalculated' ) {
			$price{'Aqueous Breakdown'} .= "AQ error: $aq_results{'alert'} $$project{'AqueousSpecs'}{alert} " . $$project{'AqueousSpecs'}{'hdnBreakdown'.$qty_index} . '<br/>';
			$price{'Comparison Cost'} += 1000000; 
		} elsif ( $aq_results{'Equipment'} ) {
			$price{'Aqueous Breakdown'} = sprintf('Aqueous Price: %dout MR $%.2f + BC: $%.2f + Service $%.2f + Material $%.2f = $%.2f on %s<br/>', $aq_results{'Imposition'}->imposition(), @aq_results{'MakeReady','Blanket','Service','Material','Total'}, $aq_results{'Equipment'}->name() );
			$price{'Comparison Cost'} += $aq_results{'Total'};
		} # end if
	} # end if Aqueous
	my %run_price;

	if ( sets::isin( $$Imposition{runstyle}, ['Work & Turn','Work & Tumble'] ) ) {
		my @c = sets::exclude( ['Varnish Gloss Overall','Varnish Matte Overall','Varnish Gloss Spot','Varnish Matte Spot','Aqueous Gloss Spot','Aqueous Gloss Overall','Aqueous Matte Spot','Aqueous Matte Overall'], [ @colours ] );
		%run_price = get_run_price( $impressions, scalar(@c), 0, $Imposition, $Press, $run_speed ); 
	} else {
		my @c1 = sets::exclude( ['Varnish Gloss Overall','Varnish Matte Overall','Varnish Gloss Spot','Varnish Matte Spot','Aqueous Gloss Spot','Aqueous Gloss Overall','Aqueous Matte Spot','Aqueous Matte Overall'], $$project{'side_one_colours'} );
		my @c2 = sets::exclude( ['Varnish Gloss Overall','Varnish Matte Overall','Varnish Gloss Spot','Varnish Matte Spot','Aqueous Gloss Spot','Aqueous Gloss Overall','Aqueous Matte Spot','Aqueous Matte Overall'], $$project{'side_two_colours'} );
		%run_price = get_run_price( $impressions, scalar @c1, scalar @c2, $Imposition, $Press, $run_speed );
	} # end if

	if ( $plate_setup{'Plate Type'} ne 'Conventional' ) {
		my %ImpositionMakeReady;
		my $service = 'ImpositionMakeReady'.$Project->Type()->name();
		if ( ! ( %ImpositionMakeReady = openprint::service::get_price_object( $service, undef, $Press ) ) ) {
			$service = 'ImpositionMakeReady';
			%ImpositionMakeReady = openprint::service::get_price_object( $service, undef, $Press );
		} # end if
		if ( ! %ImpositionMakeReady ) {
			#$openprint::log->debug("$service no price found");
		} # end if
		if ( $ImpositionMakeReady{units} eq 'Per Form' ) {
#$openprint::log->debug("Make Ready Per Form " . ($$specs{'PreviousForms'.$qty_index}+1) );
			%ImpositionMakeReady = openprint::service::get_price_object( $service, $$specs{'PreviousForms'.$qty_index} + 1, $Press );
		} # end if

		$price{'Imposition MakeReady'} = $ImpositionMakeReady{'Price'};

		$price{'Imposition Total'} = $price{'Imposition MakeReady'};
		my %ImpositionCharge;
		$service = 'Imposition'.$Project->Type()->name();

		if ( ! (%ImpositionCharge = openprint::service::get_price_object( $service,undef,$Press) ) ) {
			$service = 'Imposition';
			%ImpositionCharge = openprint::service::get_price_object( $service,undef,$Press);
		} # end if
		if ( $ImpositionCharge{'units'} eq 'Per Page' ) {
			%ImpositionCharge = openprint::service::get_price_object( $service,$Imposition->pages(),$Press);
			$price{'Imposition Total'} += $ImpositionCharge{Price} * $Imposition->pages();
		} elsif ( $ImpositionCharge{'units'} eq 'Per Square Inch of Object' ) {
			%ImpositionCharge = openprint::service::get_price_object( $service,$Imposition->layout_area(),$Press);
			$price{'Imposition Total'} += $ImpositionCharge{Price} * $Imposition->object_width() * $Imposition->object_height();
		} elsif ( $ImpositionCharge{'units'} eq 'Per Square Inch of Layout' ) {
			%ImpositionCharge = openprint::service::get_price_object( $service,$Imposition->layout_area(),$Press);
			$price{'Imposition Total'} += $ImpositionCharge{Price} * $Imposition->layout_area();
		} else {
			%ImpositionCharge = openprint::service::get_price_object( $service,$Imposition->imposition(),$Press);
			$price{'Imposition Total'} += $ImpositionCharge{Price} * $Imposition->imposition();
		} # end if
		$price{'Imposition Price'} = \%ImpositionCharge;
		$setup_cost += $price{'Imposition Total'};

		my %SteppingCharge;
		if ( ! (%SteppingCharge = openprint::service::get_price_object( 'Stepping Charge'.$Project->Type()->strid(), undef, $Press) ) ) {
			%SteppingCharge = openprint::service::get_price_object( 'Stepping Charge', undef, $Press);
		} # end if
		if ( %SteppingCharge ) {
			$SteppingCharge{'Total'} = $SteppingCharge{'Price'} * $Imposition->imposition();
			$price{'Stepping Charge'} = \%SteppingCharge;
			$setup_cost += $SteppingCharge{'Total'};
		} # end if

		if ( $Imposition->pages() ) {
			my %PageCharge;
			if ( ! ( %PageCharge = openprint::service::get_price_object( 'Page Charge'.$Project->Type()->strid(),$Imposition->pages(),$Press) ) ) {
				%PageCharge = openprint::service::get_price_object( 'Page Charge', $Imposition->pages(), $Press );
			} # end if
			if ( %PageCharge ) {
				if ( $PageCharge{'units'} eq 'Per Page' ) {
					$PageCharge{'Total'} = $PageCharge{'Price'} * $Imposition->pages();
				} # end if
				$price{'Page Charge'} = \%PageCharge;
				$setup_cost += $PageCharge{'Total'};
			} # end if Page Charge
		} # end if pages
	} # end if Plate Type Conventional

	my %RunStylePrice = openprint::service::get_price_object( $$Imposition{runstyle}.'Setup',undef,$Press );
	$price{'Runstyle Charge'} += $RunStylePrice{'Price'};
	$setup_cost += $price{'Runstyle Charge'};

	$price{'Comparison Cost'} += $setup_cost;
	$price{'Setup Total'} = $setup_cost;

	$price{'Press Setup'} = $press_setup;

	my $run_cost = $run_price{'Price'};

	$price{'Impressions'} = $impressions;
	$price{'Impression Cost'} = $run_price{'Cost'};
	$price{'Impression Units'} = $run_price{'units'};
	$price{'Impression Price'} = $run_price{'Price'};
	$price{'Impression MPrice'} = $run_price{'MPrice'};

	$price{'Minimum Run Charge'} = openprint::service::get_price( 'PressRunChargeMinimum',undef,$Press );

	if ( $run_cost < $price{'Minimum Run Charge'} ) {
		$run_cost = $price{'Minimum Run Charge'};
	} # end if
	$price{'Run Total'} = $run_cost;
	$price{'Comparison Cost'} += $run_cost;
	$price{'Comparison Cost'} += $price{'Ink Price'};
#$openprint::log->debug("Comparison Cost: $price{'Comparison Cost'}");
	$price{'Total Cost'} = $run_cost + $setup_cost + $price{'Ink Price'};

	$price{'complete'} = 1;
	return \%price;
} # end sub calc_price

sub select_presses {
# this function returns a hash of the presses with their reasons for not being used.

	my ( $Project, $Paper, $specs, $side_one_colours, $side_two_colours ) = @_;
#$log->debug("**** Start of select_press. Inputs: Project $project_index ****");

# we do not have to check Image Size here because the the imposition code will take care of that later on.
# it may be a little faster to eliminate the press now but i'm not sure.

# we do not need to do any Perfecting checks because imposition code will create or no create perfecting.

# Inline Perfing & Scoring is done as a sperate run, so it dosn't affect our printing press choice.
# Same with UV, AQ etc.

	my %results;
	my $varnish = 0;
#$log->debug(" *** CHECKING FOR VANISH *** ");
	foreach my $colour (@$side_one_colours, @$side_two_colours) {
		if ( $colour =~ /Varnish/ ) {
#$log->debug(" ** HAVE VARNISH **" );
			$varnish = 1;
		} # end if
	} # end if
	my @Coatings = map { $_->name() } openprint::Service::find('category'=>'Coating');
	my @side_one_colours = sets::exclude( \@Coatings, $side_one_colours );
	my @side_two_colours = sets::exclude( \@Coatings, $side_one_colours );

	foreach my $Press ( openprint::Equipment::find( 'category'=>'Printing', 'UseInEstimating'=>'Y' ) ) {
		my $press_id = $Press->id();

		if ( $$specs{'ScreenType'} eq 'FM' and $Press->specification('FM Screening Capable') ne 'Y' ) {
			$results{$press_id} = "Can't do FM Screening";
			next;
		} # end if

		if ( $_ = $Press->specification('ProjectTypes') ) {
			if ( sets::isin( '!'.$Project->Type()->name(), split(',',$_) ) ) {
				$results{$press_id} = "Press is set to not do " . $Project->Type()->name();
				next;
			} # end if
		} # end if

		if ( $Project->Type()->name() eq 'Envelopes' and $Press->specification('Envelope Capable') ne 'Y' ) {
			$results{$press_id} = "Failed Envelope Check";
			next;
		} # end if

		if ( $Paper->calliper() > $Press->specification('Maximum Calliper', $Paper->grade() ) ) {
			$results{$press_id} = "Press $press_id Failed Calliper Check";
			next;
		} # end if
		if ( ( $Paper->type() eq 'Roll' ) and $Press->specification('Minimum Basis Weight') and $Paper->basis_mweight() < $Press->specification('Minimum Basis Weight') ) {

			$results{$press_id} = "Failed Minimum Basis Weight Check **" . $Paper->basis_mweight() . ' < ' . $Press->specification('Minimum Basis Weight');
			next;
		} # end if

		if ( $Press->specification('Printing Type') eq 'Digital' ) {
# Digital only support Process, no PMS, etc...
			if ( ( scalar @side_one_colours == 1 ) and ( ! sets::isin( $side_one_colours[0], ['Black', 'Black Spot Colour'] ) ) ) {
				$results{$press_id} = "Digital doesn't do non-black: $side_one_colours[0]";
				next;
			} # end if
			if ( ( scalar @side_two_colours == 1 ) and ( ! sets::isin( $side_two_colours[0], ['Black', 'Black Spot Colour'] ) ) ) {
				$results{$press_id} = "Digital doesn't do non-black: $side_two_colours[0]";
				next;
			} # end if

			if ( scalar @side_one_colours > 1 and scalar @side_one_colours < 4 ) {
				$results{$press_id} = "Digital doesn't do non-process";
				next;
			} # end if
			if ( scalar @side_one_colours > 4 ) {
				$results{$press_id} = "Digital doesn't do non-process";
				next;
			} # end if
			if ( scalar @side_two_colours > 1 and scalar @side_two_colours < 4 ) {
				$results{$press_id} = "Digital doesn't do non-process";
				next;
			} # end if
			if ( scalar @side_two_colours > 4 ) {
				$results{$press_id} = "Digital doesn't do non-process";
				next;
			} # end if
			if ( ( scalar @side_one_colours == 4 ) and sets::intersection( @side_one_colours, 'Cyan', 'Magenta', 'Yellow','Black' ) != 4 ) {
				$results{$press_id} = "Digital doesn't do non-process";
				next;
			} # end if
			if ( ( scalar @side_two_colours == 4 ) and sets::intersection( @side_two_colours, 'Cyan', 'Magenta', 'Yellow','Black' ) != 4 ) {
				$results{$press_id} = "Digital doesn't do non-process";
				next;
			} # end if
		} # end if

		if ( ( @side_one_colours > $Press->specification('Number of Colours') or @side_two_colours > $Press->specification('Number of Colours') ) and $Press->specification('Multipass', $Paper->gsm()) eq 'N' ) {
			$results{$press_id} = "Too many colours and no multipass.";
			next;
		} elsif ( $Press->specification('Web Press') eq 'Y' ) {
			if ( @side_one_colours > $Press->specification('Number of Colours') ) {
				$results{$press_id} = "Too many colours for web.";
				next;
			} elsif ( @side_two_colours > $Press->specification('Number of Colours') ) {
				$results{$press_id} = "Too many colours for web.";
				next;
			} # end if
		} # end if

		if ( $varnish ) {
			if ( $Press->specification('Varnish Capable') ne 'Y' ) {
				$results{$press_id} = "Failed varnish check.";
				next;
			} # end if
		} # end if
		$results{$press_id} = '';
	} # end while

	return %results;
} # end sub select_press

sub get_varnish_run_price {
	my ( $log, $dbh, $variable, $Press, $print_sides, $impressions, $specs, $side_one_colours, $side_two_colours, $qty_index, $Imposition, $Project, $service_index, $inkCoverage ) = @_;

	my %varnish_price;
	my $varnish_sides;
#$log->debug("***************** START OF GET VARNISH PRICE *********************");

# How many varnishes we have per sheet...
	foreach my $colour (@$side_one_colours, @$side_two_colours) {
		if ( $colour =~ /Varnish/ ) {
#$log->debug("***************** VARNISH CHECK: $colour DT: $dry_trap **********************");
			$varnish_sides += 1;
		} # end if
	} # end for each
	return if ! $varnish_sides;
		
	my %price = openprint::service::get_price_object( $log, $dbh, $variable, 'VarnishMakeReady', 1, $Press);
	if ( $price{'units'} eq 'Per Form' ) {
		my $previous_forms = 0;
 #$$specs{'PreviousForms'};
# Need to figure out how many similar forms we have
		foreach my $ss_id ( $Project->signatures() ) {
			next if $service_index and ($ss_id >= $service_index);
			my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
			next if $$sig_specs{'pages_supplied'} eq 'Y';
			$previous_forms += 1 if compare_signatures_runstyle( $specs, $sig_specs, $qty_index );
		} # end foreach
		#$openprint::log->debug("Previous Forms $previous_forms");
		#$$specs{'PreviousForms'} = $previous_forms;

		%price = openprint::service::get_price_object( $log, $dbh, $variable, 'VarnishMakeReady', $previous_forms + 1, $Press);
	} # end if
	$varnish_price{'Setup'} = $price{'Price'};


	if ( $$specs{'chkVarnishDryTrapSideOne'} or $$specs{'chkVarnishDryTrapSideTwo'} ) {
		%price = openprint::service::get_price_object( $log, $dbh, $variable, 'VarnishDryTrap', $impressions, $Press);
	} else {
		%price = openprint::service::get_price_object( $log, $dbh, $variable, 'VarnishInLine', $impressions, $Press);
	} # end if
	if ( sets::isin( lc $price{'units'}, [ 'per m', 'per 1000' ] ) ) {
		$price{'Run Price'} = $price{'Price'};
		$price{'Total'} = $price{'Price'} * $impressions/1000;
		$price{'Total'} /= 2 if ($varnish_sides == 1);
	} # end if
	$varnish_price{'run_price'} = $price{'Run Price'};
	$varnish_price{'Run Total'} = $price{'Total'};
	$varnish_price{'Run Units'} = $price{'units'};

	foreach my $c ( @$side_one_colours, @$side_two_colours) {
		my $colour = $c;
		next if ! ( $colour =~ /Varnish/ );

		my $area ;
		if ( $colour =~ /Spot/ ) {
			if ( $colour =~ /Gloss/ ) {
				$colour = 'GlossVarnish';
			} elsif ( $colour =~ /Matte/ ) {
				$colour = 'MatteVarnish';
			} # end if
			$area = $Imposition->object_area() * $$inkCoverage{$colour}/100;
			if ( sets::isin( $c, $side_one_colours ) and sets::isin( $c, $side_two_colours ) ) {
				$area /= 2;
			} # end if
		} else { # Overall
			if ( $colour =~ /Gloss/ ) {
				$colour = 'GlossVarnish';
			} elsif ( $colour =~ /Matte/ ) {
				$colour = 'MatteVarnish';
			} # end if
			$area = $Imposition->layout_area();
		} # end if
		if ( my @materials = openprint::Material::find('name'=>$colour) ) {
			%price = $materials[0]->get_price( undef, $Press );
		} # end if
		if ( ! %price ) {
			$colour = 'Varnish';
			if ( my @materials = openprint::Material::find('name'=>$colour) ) {
				%price = $materials[0]->get_price( undef, $Press );
			} # end if
		} # end if

		$varnish_price{'Material Units'} = $price{'units'};

		if ( lc $price{'units'} eq 'per square foot' ) {
			my $p = $price{'Price'} * $area/144;
			$varnish_price{'Material Price'} += $p;
			$varnish_price{'Material Total'} += $p * $impressions;
		} elsif ( lc $price{'units'} eq 'per square inch' ) {
			my $p = $price{'Price'} * $area;
			$varnish_price{'Material Price'} += $p;
			$varnish_price{'Material Total'} += $p * $impressions;
		} elsif ( lc $price{'units'} eq 'per kg' ) {
			my $grade = $Imposition->Paper()->grade();
			$grade = 4 if ! $grade;

			if ( my @Materials = openprint::Material::find('name'=>$colour) ) {
				my $Material = $Materials[0];
				my $coverage = $Material->specification('Coverage', $grade);
				my $qty = ceil( $area*$impressions/$coverage ) if $coverage;
				my %price = $Material->get_price( $qty, $Press );
				$price{'Total'} = $price{'Price'} * $qty;
				$varnish_price{'Material Price'} += $price{'Total'};
				$varnish_price{'Material Total'} += $price{'Total'};
				$varnish_price{'Breakdown'} .= sprintf('%s at %.2f%s * %dKg = $%.2f<br/>', $c, @price{'Price','units'}, $qty, $price{'Total'} );
			} # end if
		} # end if
	} # end foreach

#$log->debug(" **************** VARNISH RUN PRICE: $run_price * VS: $varnish_sides PS: $print_sides *********************");
	$varnish_price{'Press Washes'} = $varnish_sides;
	return %varnish_price;
} # end if

sub get_run_price {
	my ( $impressions, $side_one_colours, $side_two_colours, $Imposition, $Press, $run_speed ) = @_;

	my %run_price;
	my $running_price = 0;
	my $max_colours = $Press->specification('Number of Colours');
	if ( ! $max_colours ) {
		$openprint::log->error(" ***** FATAL ERROR: Could Not Get 'Number of Colours' for Press: $Press->strid() ***********");
		return %run_price;
	} # end if
	my $impression_service = $Imposition->runstyle() eq 'Perfecting' ? 'ColourImpressionPerfecting' : 'ColourImpression';
	my %RunPrice;

	if ( $Imposition->runstyle() eq 'Web' ) {
# A web does both sides at once, and cannot do multipass
		$impression_service = 'WebImpression'.$side_one_colours.'/'.$side_two_colours;
		if ( ! ( %RunPrice = openprint::service::get_price_object( 'WebImpression'.$side_one_colours.'/'.$side_two_colours, $impressions, $Press ) ) ) {
			%RunPrice = openprint::service::get_price_object( 'WebImpression', $impressions, $Press );
		} # end if
		$run_price{'units'} = $RunPrice{'units'};
		$running_price = $RunPrice{'Price'};
#$openprint::log->debug("Price: $running_price");
	} elsif ( $Imposition->runstyle() eq 'Perfecting' ) {
		$impression_service = 'PerfectingImpression'.$side_one_colours.'/'.$side_two_colours;
		if ( ! ( %RunPrice = openprint::service::get_price_object( 'PerfectingImpression'.$side_one_colours.'/'.$side_two_colours, $impressions, $Press ) ) ) {
			%RunPrice = openprint::service::get_price_object( 'PerfectingImpression', $impressions, $Press );
		} # end if
		$run_price{'units'} = $RunPrice{'units'};
		$running_price = $RunPrice{'Price'};
	} else {
		if ( $side_one_colours ) {
			my $full_runs = int($side_one_colours / $max_colours);
			if ( $full_runs ) {
				my $run_colours = $side_one_colours > $max_colours ? $max_colours : $side_one_colours;
				my %RunPrice = openprint::service::get_price_object( $run_colours.$impression_service, $impressions, $Press );
				$run_price{'units'} = $RunPrice{'units'};
				$running_price = $RunPrice{'Price'} * $full_runs;
			} # end if
#$log->debug("**** RUN PRICE 2 : $running_price **") if $debug;

			my $mod_colours = $side_one_colours % $max_colours;
			if ( $mod_colours ) {
				my %RunPrice = openprint::service::get_price_object( $mod_colours.$impression_service, $impressions, $Press);
				$running_price += $RunPrice{'Price'};
				$run_price{'units'} = $RunPrice{'units'} if ! $run_price{'units'};
#$log->debug("**** RUN PRICE 3 : $running_price **") if $debug;
			} # end if
		} # end if
#$log->debug(" ** SIDE ONE RUNNING PRICE $running_price **");
		if ( $side_two_colours ) {
			my $full_runs = int($side_two_colours / $max_colours);
			if ( $full_runs ) {
				my $run_colours = $side_two_colours > $max_colours ? $max_colours : $side_two_colours;
				my %RunPrice = openprint::service::get_price_object( $run_colours.$impression_service, $impressions, $Press );
				$running_price += $RunPrice{'Price'} * $full_runs;
				$run_price{'units'} = $RunPrice{'units'} if ! $run_price{'units'};
			} # end if
##$log->debug("**** RUN PRICE 4 : $running_price **") if $debug;
#
			my $mod_colours = $side_two_colours % $max_colours;
			if ( $mod_colours ) {
				my %RunPrice = openprint::service::get_price_object( $mod_colours.$impression_service, $impressions, $Press);
				$running_price += $RunPrice{'Price'};
				$run_price{'units'} = $RunPrice{'units'} if ! $run_price{'units'};
			} # end if
			if ( $side_one_colours ) {
# This is here beacuse impressions are doubled
				$running_price /= 2;
#$log->debug("**** RUN PRICE 5 : $running_price **") if $debug;
			} # end if
		} # end if
	} # end if
	if ( $side_one_colours > $max_colours or $side_two_colours > $max_colours ) {
		$run_price{'MultiPass Run'} = 1;
	} else {
		$run_price{'MultiPass Run'} = 0;
	} # end if

# now work out the press run speed

	my $std_speed = $Press->Specification('Run Speed' );
	
	my $speed_mod;
	if ( $std_speed ) {
		my $Paper = $Imposition->Paper();

# Only load this if not already specified by some inline bindery service
		$run_speed = $Press->specification('Run Speed', ($$std_speed{'units'} eq 'Calliper' ? $Paper->calliper() : $Paper->gsm()), 1 ) if ! $run_speed;
		if ( ! $run_speed ) {
			$openprint::log->error("No run sped on $$Press{strid} for $$std_speed{'units'} " . ($$std_speed{'units'} eq 'Calliper' ? $Paper->calliper() : $Paper->gsm() ) );
		} elsif ( $run_speed == $$std_speed{'value'} ) {
			$speed_mod = $Press->specification('Press Additional Run Speed',$Paper->calliper());
			#$openprint::log->warn("1Press ".$Press->strid()." Calliper: $$Paper{calliper} gsm: $$Paper{gsm} ($running_price) ($run_price{'units'}) STD: ($$std_speed{value}) RUN ($run_speed), mod: $speed_mod,  std/run: " . ( $speed_mod ? $run_speed/$speed_mod : $$std_speed{'value'}/$run_speed ) ) if $debug;
			$speed_mod = $run_speed / $speed_mod if $speed_mod;
		} else {
			#$openprint::log->warn("1Press ".$Press->strid()." Calliper: $$Paper{calliper} gsm: $$Paper{gsm} ($running_price) ($run_price{'units'}) STD: ($$std_speed{'value'}) RUN ($run_speed), mod: $speed_mod,  std/run: " . ( $speed_mod ? $run_speed/$speed_mod : $std_speed/$run_speed ) ) if $debug;
			$speed_mod = $$std_speed{'value'} / $run_speed;
		} # end if
	} # end if

	if ( sets::isin( lc $run_price{'units'}, ['per m','per 1000 impressions', 'per 1000'] ) ) {
		if ( $speed_mod ) {
			$running_price *= $speed_mod;
		} # end if
#$log->warn(" ** FINAL  RUNNING PRICE $running_price **") if $debug or 1;
		$run_price{'Cost'} = $running_price;
		$run_price{'Price'} = ($run_price{'Cost'} * $impressions)/1000;
		$run_price{'MPrice'} = $run_price{'Cost'};

	} elsif ( lc $run_price{'units'} eq 'per hour' ) {
		if ( $run_speed ) {
# In Minutes, not hours
			$run_price{'RunHours'} = $impressions / $run_speed;
			$run_price{'RunTime'} = int ( 60 * $impressions / $run_speed );
		} # end if
		$run_price{'Cost'} = $running_price;
		$run_price{'Price'} = $running_price * $run_price{'RunHours'};
		$run_price{'MPrice'} = ( $run_price{'Price'} / $impressions ) * 1000;
	} else {
		$openprint::log->warn("Unknown Units for $impression_service: ($run_price{'units'}) on " . $Press->strid() );
	} # end if
#$openprint::log->debug("Impresion price: $run_price{'Cost'} $run_price{'units'} = $run_price{'Price'}");
	return %run_price;
} # end sub get_run_price

# This is called once perside, or just once for W&T
sub press_setup_cost {
	my ( $Press, $plate_change_qty, $plate_runs, $colours, $calliper, $specs, $qty_index, $service_index, $Imposition ) = @_;

	my $setup_count = 0;

	foreach my $colour ( @$colours ) {
		next if $colour =~ /Aqueous/;
		next if $colour =~ /UV/;
		if ( $colour eq 'InlineBinderyNoPlate' ) {
# no plate
		} elsif ( $colour =~ /^Overall Varnish/ ) {
			$setup_count += 1;
		} elsif ( $colour =~ /^Spot Varnish/ ) {
#           if we don't already have and overall of the same type then add a plate.
			$setup_count += 1;
		} else {
			$setup_count += 1;
		} # end if
	} # end foreach colour
	
	my %Price;
	$Price{'Setup Count'} = $setup_count + $plate_change_qty;
	if ( ! ( %Price = openprint::service::get_price_object( 'PressUnitMakeReady'.$Imposition->runstyle(), undef, $Press ) ) ) {
		%Price = openprint::service::get_price_object( 'PressUnitMakeReady', undef, $Press );
	} # end if
	if ( $Price{'units'} eq 'Stock Calliper - Per Plate' ) {
		%Price = openprint::service::get_price_object( 'PressUnitMakeReady', $calliper, $Press);
		$Price{'Total'} = $Price{'Price'} * $setup_count;
	} elsif ( $Price{'units'} eq 'Per Form' ) {
		%Price = openprint::service::get_price_object( 'PressUnitMakeReady', $$specs{'PreviousForms'.$qty_index} + 1, $Press);
		$Price{'Total'} = $Price{'Price'};
	} elsif ( $Price{'units'} eq 'Total' ) {
		if ( ! ( %Price = openprint::service::get_price_object( 'PressUnitMakeReady'.$Imposition->runstyle(), $setup_count, $Press ) ) ) {
			%Price = openprint::service::get_price_object( 'PressUnitMakeReady', $setup_count, $Press );
		} # end if
		$Price{'Total'} = $Price{'Price'};
	} else { # Per Unit
		if ( ! ( %Price = openprint::service::get_price_object( 'PressUnitMakeReady'.$Imposition->runstyle(), $setup_count, $Press ) ) ) {
			%Price = openprint::service::get_price_object( 'PressUnitMakeReady', $setup_count, $Press );
		} # end if
		$Price{'Total'} = $Price{'Price'} * $setup_count;
	} # end if
	if ( $Price{'units'} =~ /Per Run/i ) {
		$Price{'Total'} *= $plate_runs if $plate_runs;
		#$Price{'Total'} *= $plate_change_qty if $plate_change_qty;
	} # end if
	$Price{'Press Setup'} = $Price{'Total'};
	my %PlateSetupPrice = openprint::service::get_price_object( 'PlateMakeReady'.$Imposition->runstyle(), undef, $Press );
	%PlateSetupPrice = openprint::service::get_price_object( 'PlateMakeReady', undef, $Press ) if ! %PlateSetupPrice;
	if ( %PlateSetupPrice ) {
		my $plates = $setup_count;
		$plates *= $plate_runs if $plate_runs;
		$plates += $plate_change_qty;
		$Price{'Plate Count'} = $plates;
		if ( lc $PlateSetupPrice{'units'} eq 'per hour' ) {
			my $time = $Press->specification('Plate Setup Time') * $plates / 60;
			$Price{'Plate Total'} = $PlateSetupPrice{'Price'} * $time;
		} elsif ( lc $PlateSetupPrice{'units'} eq 'per plate' ) {
			%PlateSetupPrice = openprint::service::get_price_object( $PlateSetupPrice{'ServiceName'}, $plates, $Press );
			$Price{'Plate Total'} = $PlateSetupPrice{'Price'} * $plates;
		} else {
			$openprint::log->error("Invalid units in PlateSetupPrice ($PlateSetupPrice{'units'})");
		} # end if
		$Price{'Plate Units'} = $PlateSetupPrice{'units'};
		$Price{'Plate Price'} = $PlateSetupPrice{'Price'};
	#} else{
		#$log->debug("No Plate Make Ready for plates on " . $Press->strid() );
	} # end if

	$Price{'Unit Count'} = $setup_count;
	return \%Price;
} # end sub press_setup_cost

# This is only called for work and turn
sub filter_colours {
	my ( @colours ) = @_;
	my @filtered_colours = ();

#$log->debug("*************** START OF FILTER COLOURS colours: @colours **************************");

	foreach my $colour ( @colours ) {
		if ( ! sets::isin( $colour, \@filtered_colours ) ) {
# We only need one black
			if ( $colour eq 'Black' ) {
				if ( ! sets::isin('Black Spot Colour', \@filtered_colours) and ! sets::isin('Black', \@filtered_colours) ) {
					push @filtered_colours, $colour;
				} # end if
			} elsif ( $colour eq 'Black Spot Colour' ) {
				if ( ! sets::isin('Black', \@filtered_colours) and ! sets::isin('Black Spot Colour', \@filtered_colours ) ) {
					push @filtered_colours, $colour;
				} # end if
			} elsif ( $colour eq 'Overall Gloss Varnish' ) {
# Overall Varnishes become Spots when Work & Turn and not Overall on Both Sides
				if ( ! sets::isin('Spot Gloss Varnish', \@colours ) ) {
					push @filtered_colours, $colour;
				} # end if
			} elsif ( $colour eq 'Overall Matte Varnish' ) {
# Overall Varnishes become Spots when Work & Turn and not Overall on Both Sides
				if ( ! sets::isin('Spot Matte Varnish', \@colours ) ) {
					push @filtered_colours, $colour;
				} # end if
			} else {
				if ( ! sets::isin( $colour, \@filtered_colours) ) {
#$log->debug("****** ADDING COLOUR: $colour ***********");
					push @filtered_colours, $colour;
				} # end if
			} # end if
		} # end if
	} # end foreach
#$log->debug("*************** END OF FILTER COLOURS colours: @filtered_colours **************************");
	return @filtered_colours;
} # end sub

sub compare_signatures_runstyle {
	my ( $sig1, $sig2, $qty_index ) = @_;
	foreach my $q_i ( $qty_index ? ( $qty_index ) : ( 1 .. 3 ) ) {
		foreach my $key ( 'ddmRunStyle', 'ddmPress','PageQuantity','txtImposition','ddmBleedSize' ) {
			if ( $$sig1{$key.$q_i} ne $$sig2{$key.$q_i} ) {
#$openprint::log->debug("Not the same $key $$sig1{ServiceIndex} $$sig2{ServiceIndex} $$sig1{$key.$q_i} $$sig2{$key.$q_i} $$sig1{SignatureIndex} $$sig2{SignatureIndex}");
				return 0;
			} # end if
		} # end if
	} # end foreach q_i
	foreach my $key (
			'txtWidth','txtHeight',
			'chkProcessColourSideOne', 'chkProcessColourSideTwo',
			'chkCyanSideOne','chkMagentaSideOne','chkYellowSideOne','chkBlackSideOne',
			'chkCyanSideTwo','chkMagentaSideTwo','chkYellowSideTwo','chkBlackSideTwo',
			'ColourCoatingType1SideOne', 'ColourCoatingColour1SideOne', 'ColourCoatingCoverage1SideOne',
			'ColourCoatingType2SideOne', 'ColourCoatingColour2SideOne', 'ColourCoatingCoverage2SideOne',
			'ColourCoatingType3SideOne', 'ColourCoatingColour3SideOne', 'ColourCoatingCoverage3SideOne',
			'ColourCoatingType4SideOne', 'ColourCoatingColour4SideOne', 'ColourCoatingCoverage4SideOne',
			'ColourCoatingType5SideOne', 'ColourCoatingColour5SideOne', 'ColourCoatingCoverage5SideOne',
			'ColourCoatingType6SideOne', 'ColourCoatingColour6SideOne', 'ColourCoatingCoverage6SideOne',
			'ColourCoatingType7SideOne', 'ColourCoatingColour7SideOne', 'ColourCoatingCoverage7SideOne',
			'ColourCoatingType8SideOne', 'ColourCoatingColour8SideOne', 'ColourCoatingCoverage8SideOne',
			'ColourCoatingType1SideTwo', 'ColourCoatingColour1SideTwo', 'ColourCoatingCoverage1SideTwo',
			'ColourCoatingType2SideTwo', 'ColourCoatingColour2SideTwo', 'ColourCoatingCoverage2SideTwo',
			'ColourCoatingType3SideTwo', 'ColourCoatingColour3SideTwo', 'ColourCoatingCoverage3SideTwo',
			'ColourCoatingType4SideTwo', 'ColourCoatingColour4SideTwo', 'ColourCoatingCoverage4SideTwo',
			'ColourCoatingType5SideTwo', 'ColourCoatingColour5SideTwo', 'ColourCoatingCoverage5SideTwo',
			'ColourCoatingType6SideTwo', 'ColourCoatingColour6SideTwo', 'ColourCoatingCoverage6SideTwo',
			'ColourCoatingType7SideTwo', 'ColourCoatingColour7SideTwo', 'ColourCoatingCoverage7SideTwo',
			'ColourCoatingType8SideTwo', 'ColourCoatingColour8SideTwo', 'ColourCoatingCoverage8SideTwo',
			'BleedLeft','BleedRight','BleedTop','BleedBottom',
			) {
				if ( $$sig1{$key} ne $$sig2{$key} ) {
#$openprint::log->debug("Not the same $key $$sig1{ServiceIndex} $$sig2{ServiceIndex} $$sig1{$key} ne $$sig2{$key}");
					return 0;
				} # end if
			} # end foreach
	return 1;
}
# compares two signature services in terms of their inputs, and returns true if equal, false if not
sub compare_signatures {
	my ( $sig1, $sig2, $qty_index ) = @_;
	return 0 if ! compare_signatures_runstyle( $sig1, $sig2, $qty_index );
	foreach my $key (
			'Group',
			'CustomStockPrice','txtCustomMWeight',
			'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour',
			'txtSpecificStockWidth', 'txtSpecificStockHeight',
			'ddmStockBrand', 'ddmStockFinish', 'ddmStockColour', 'ddmStockWeight',
			'rdbSuppliedStock','rdbSpecificStock','txtEmployeeComments',
			) {
		if ( $$sig1{$key} ne $$sig2{$key} ) {
#$openprint::log->debug("Not the same $key $$sig1{ServiceIndex} $$sig2{ServiceIndex} $$sig1{$key} ne $$sig2{$key}");
			return 0
		} # end if
	} # end foreach
#foreach my $key ( 'txtStockGSM' ) {
#if ( sprintf('%.0f', $$sig1{$key}) ne sprintf('%.0f', $$sig2{$key}) ) {
##$openprint::log->debug("Not the same $key $$sig1{ServiceIndex} $$sig2{ServiceIndex} $$sig1{$key} ne $$sig2{$key}");
#return 0
#} # end if
#} # end foreach

	return 1;
} # end sub compare_signatures

sub runtime {
	my ( $Project, $specs, $Equipment, $impressions, $runspeed ) = @_;

    my $qty_index = $Project->ordered_quantity_index();
	my %time;

	if ( ! $Equipment ) {
		$Equipment = openprint::Equipment::find_one( 'strid'=>$$specs{'UsePress'} );
		if ( ! $$specs{'UsePress'} ) {
			$$specs{'UsePress'} = $$specs{'ddmPress'.$qty_index};
		} # end if
	} # end if
	if ( ! $Equipment ) {
		$openprint::log->error("No equipment found for $$specs{'UsePress'}");
		return %time;
	} # end if

	my @Equipment = openprint::Equipment::find( 'strid'=>$$specs{'UsePress'} );
	my $Equipment = shift @Equipment;
	my @side_one_colours = get_colours( $specs, 'SideOne' );
	my @side_two_colours = get_colours( $specs, 'SideTwo' );
	my @colours;
	if ( sets::isin( $$specs{'ddmRunStyle'.$qty_index}, ['Work & Turn', 'Work & Tumble'] ) ) {
		@colours = openprint::Estimating::Printing::filter_colours( @side_one_colours, @side_two_colours );
	} else {
		@colours = ( @side_one_colours, @side_two_colours );
	} # end if

	$time{'Setup'} = 0;

	$time{'Setup'} += 60*$Equipment->specification('Setup Time') if @side_one_colours;
	$time{'Setup'} += 60*$Equipment->specification('Setup Time') if @side_two_colours;
	$time{'Setup'} += 60*$Equipment->specification('Wash Up Time Per Colour') * @colours;

	$runspeed = runspeed( $Project, $specs, $qty_index, $Equipment ) if ! $runspeed;
	$impressions = $$specs{'hdnImpressionQuantity'.$qty_index} if ! $impressions;
	if ( $runspeed ) {
		$time{'Run'} += int ( 3600 * $impressions / $runspeed );
	} # end if
	$time{'Total'} = $time{'Setup'} + $time{'Run'};
#$openprint::log->debug("Total: $time{'Setup'} + $time{'Run'} = $time{'Total'} => " . misc::seconds2hms( $time{'Total'} ) );
	return \%time;
} # end sub runtime

sub runspeed {
	my ( $Project, $sig_specs, $qty_index, $Equipment ) = @_;

	my $runspeed;
	if ( ! $Equipment ) {
#$openprint::log->debug("SIGSPECS $sig_specs, PROJECT: $Project ");
		my $equipment_name = $$sig_specs{'UsePress'} ? $$sig_specs{'UsePress'} : $$sig_specs{'ddmPress'.$qty_index};
		if ( ! $equipment_name ) {
			$openprint::log->error( "No equipmnet in sig for qty $qty_index" );
			return;
		} # end if
		$Equipment = openprint::Equipment::find_one('strid'=>$equipment_name);
		if ( ! $Equipment ) {
			$openprint::log->error( "Equipment $equipment_name not found in runspeed" );
			return;
		} # end if
	} # end if

	my $Imposition = new openprint::Imposition();
	$Imposition->load( $sig_specs, $qty_index );

	if ( $Equipment->specification('Folding Capable') eq 'When Printing' ) {
		my $services = $Project->services();
		if ( $$services{'Folding'} ) {
			my $fold_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );
			if ( $$fold_specs{'ddmEquipment-'.$$sig_specs{'SignatureIndex'}.'-'.$qty_index} == $Equipment->id() ) {
				my $foldtype = sprintf('%sx%s-%dPage-%sSignatureFold', $Imposition->get('spread_columns','spread_rows','pages','image_orientation' ) );
				$runspeed = int( $Equipment->specification($foldtype.'RunSpeed', $Imposition->Paper()->gsm() ) );
#$openprint::log->debug("Foudn runspeed for fold $foldtype: $runspeed");
			} # end if
		} # end if
	} # end if
    if ( ! $runspeed ) {
        $runspeed = int( $Equipment->specification( 'Press Additional Run Speed', $$sig_specs{'txtSpecificStockCalliper'} ) );
#$openprint::log->debug("Foudn Additional runspeed for $$Equipment{strid}: $runspeed");
    } # end if
    if ( ! $runspeed ) {
        $runspeed = int( $Equipment->specification('Run Speed', $Imposition->Paper()->gsm() ) );
#$openprint::log->debug("Foudn Standard runspeed for $$Equipment{strid}: $runspeed");
    } # end if
	return $runspeed;
} # end sub runspeed

sub get_weight {
	my ( $Project, $specs, $qty_index ) = @_;

	my $Paper = openprint::Paper::load_from_signature( $Project, $specs, $qty_index );
	my $sig_weight = $$specs{'txtWidth'} * $$specs{'txtHeight'} * $Paper->wpsi();
#$openprint::log->debug("Get_weight: ($$specs{'txtSignatureSpreadQuantity'.$qty_index} > 0 ? $$specs{'txtSignatureSpreadQuantity'.$qty_index} : 1 ) * ( $$specs{'txtWidth'} * $$specs{'txtHeight'} ) * ".$Paper->gsm().'gsm '.$Paper->wpsi() . '==='.$Paper->wpsi(undef)."wpsi = $sig_weight * $$specs{'PageQuantity'} = " . $sig_weight * $$specs{'PageQuantity'});

	if ( $$specs{'PageQuantity'.$qty_index} ) {
		$sig_weight *= $$specs{'PageQuantity'.$qty_index}/$$specs{'txtSpreadSize'};
	} # end if
# This is business cards, etc.
	if ( $$specs{'PageQuantity'} ) {
# For Scratch Pads
		$sig_weight *= $$specs{'PageQuantity'};
	} # end if
	return $sig_weight;
} # end sub get_weight

sub group_summary {
} # end sub group_summary

sub summary {
	my ( $Project, $service_index, $specs, $qty_index ) = @_;

	my $services = $Project->services();
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] ) if $$services{''};

	if ( $qty_index ) {
		if ( ! $$specs{'txtSpreadSize'} ) {
			$$specs{'txtSpreadSize'} = $$printing_specs{'txtSpreadSize'};
		} # end if
		return '' if ! $$specs{'txtImposition'.$qty_index};
		my $html = sprintf(qq{%s %dout %s},
				$$specs{'PageQuantity'.$qty_index} ? $$specs{'PageQuantity'.$qty_index}.'pp' : '',
				$$specs{'txtImposition'.$qty_index},
				($$specs{'ddmRunStyle'.$qty_index} eq 'Web' ? $$specs{'StockWidth'.$qty_index} . '" ' . ssi::htmlize($$specs{'ddmRunStyle'.$qty_index}) : ssi::htmlize($$specs{'ddmRunStyle'.$qty_index}) ), 
				);
		#$html .= sprintf(qq{ on %s\n}, $$specs{'ddmPress'.$qty_index} ) if ! $$services{'NoPrinting'};

#$html .= $$specs{'ddmRunStyle'.$qty_index} eq 'Web' ? $$specs{'StockWidth'.$qty_index} . '" ' . $$specs{'ddmRunStyle'.$qty_index} : $$specs{'ddmRunStyle'.$qty_index};
		$html .= sprintf(' with %d plate changes = %d plates', @$specs{'txtPlateChangeQuantity'.$qty_index,'txtPlateQuantity'.$qty_index} ) if $$specs{'txtPlateChangeQuantity'.$qty_index};

		if ( $$services{'NoPrinting'} ) {
			$html .= sprintf(' %s" x %s"', @$specs{'StockWidth'.$qty_index,'StockHeight'.$qty_index});
		} else {
			$html .= ' Stock Qty: ' . $$specs{'txtPressSheetQty'.$qty_index};
			if ( $$specs{'StockType'.$qty_index} eq 'Roll' ) {
				if ( $$specs{'ddmRunStyle'.$qty_index} ne 'Web' ) {
					$html .= sprintf( ' of %s" Roll.  Cut Off: %s"',  @$specs{'StockWidth'.$qty_index,'StockHeight'.$qty_index});
				} # end if
			} else {
				$html .= sprintf(' of %s" x %s"', @$specs{'StockWidth'.$qty_index,'StockHeight'.$qty_index});
			} # end if
		} # end if

		return $html;
	} else {
		my $dimensions = '';
		if ( $$specs{'txtSignatureType'} ) {
			if ( $$specs{'txtFinalWidth'} and $$specs{'txtFinalHeight'} ) {
				$dimensions .= sprintf( '%s&quot;x%s&quot; ', @$specs{'txtFinalWidth','txtFinalHeight'});
			} else {
				$dimensions .= sprintf( '%s&quot;x%s&quot; ', @$printing_specs{'txtFinalWidth','txtFinalHeight'});
			} # end if
		} elsif ( ( $$specs{'txtFinalWidth'} and $$specs{'txtFinalHeight'} ) and ( $$specs{'txtFinalWidth'} != $$specs{'txtWidth'} or $$specs{'txtFinalHeight'} != $$specs{'txtHeight'} ) ) {
			if ( $$services{'Folding'} ) {
				$dimensions .= sprintf( '%s&quot;x%s&quot; folded to %s&quot;x%s&quot; ',
						@$specs{'txtWidth','txtHeight','txtFinalWidth','txtFinalHeight'});
			} else {
				$dimensions .= sprintf( '%s&quot;x%s&quot; -> %s&quot;x%s&quot; ',
						@$specs{'txtWidth','txtHeight','txtFinalWidth','txtFinalHeight'});
			} # end if
		} else {
			$dimensions .= sprintf( '%s&quot;x%s&quot; ', @$specs{'txtWidth','txtHeight'});
		} # end if

		my $string = sprintf( '%s %s', ($$specs{'txtServiceDescription'} ? $$specs{'txtServiceDescription'} . ':' : ''), $dimensions );
		if ( ! $$services{'NoPrinting'} ) {
			$string .= sprintf( ' %s on %s %s',
					get_colour_description( $specs ),
					$$specs{'rdbSuppliedStock'} eq 'Y' ? '<b>Customer Supplied</b>' : '',
					$$specs{'rdbSpecificStock'} eq 'Y' ?
					join(', ', @$specs{'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour','txtSpecificStockWeight'} ) :
					join(', ', @$specs{'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight'} )
					,
					);
		} # end if
		if ( $$specs{'pages_supplied'} eq 'Y' ) {
			$string .= ' pages supplied by customer as ';
			if ( $$specs{'supplied_format'} eq 'Sheets' ) {
				$string .= ' flat sheets.';
			} elsif ( $$specs{'supplied_format'} eq 'Folded' ) {
				$string .= ' folded pages.';
			} # end if
		} # end if
		return $string;
	} # end if
} # end sub summary


sub save {
	my ( $p_id, $s_id, $param ) = @_;
	my $Project = new openprint::Project( $p_id );
	my $services = $Project->services();

	if ( $$services{'Padding'} ) {
		foreach my $padding_id ( @{$$services{'Padding'}} ) {
			openprint::service::insert_service_spec( $openprint::log, $openprint::dbh, $p_id, $padding_id, 'PageQuantity', $$param{'PageQuantity'} );
		} # end foreach
	} # end if adding

} # end sub save

sub get_colour_description {
	my ( $specs ) = @_;
	my $front_colours = 0;
	my $front_coatings;
	my $front_pms = 0;
	my $front_process = 0;
	my $back_colours = 0;
	my $back_coatings;
	my $coatings = '';
	my $back_pms = 0;
	my $back_process = 0;

	my $colorsideone = '';
	my $colorsidetwo = '';

	my $side = 'SideOne';
	foreach my $colour ( 'Cyan','Magenta','Yellow','Black' ) {
		if ( $$specs{'chk'.$colour.$side} ) {
			$front_colours += 1;
			if ( $colorsideone ){
				$colorsideone .= ' ';
			}
			$colorsideone .= $colour;
		} # end if
	} # end foreach

	if ( $$specs{'chkProcessColour'.$side} ) {
		$front_colours += 4;
	} # end if

	foreach my $k ( keys %$specs ) {
		if ( my ( $index ) = $k =~ /^chkColourCoating(\d+)$side/ ) {
			next if ! $$specs{"chkColourCoating$index$side"};

			my $type = $$specs{"ColourCoatingType$index$side"};
			next if ! $type;
			next if $$specs{"chkColourCoatingColour$index$side"} eq 'None';
			if ( $type =~ /Aqueous/ or $type =~ /Varnish/ or $type =~ /UV/ ) {
				$front_coatings .= '+'.$$specs{"ColourCoatingType$index$side"};
			} elsif ( $type =~ /PMS/i ) {
				$front_pms += 1;
			} elsif ( $type =~ /Metallic/i ) {
				$front_coatings .= '+Metallic' if ! ($front_coatings =~ /Metallic/);
			} else {
				$front_coatings .= '+'.$$specs{"ColourCoatingType$index$side"}; 	#line added to show other types june-18-2008
					$front_colours += 1;
			} # end if
		} # end if
	} # end foreach
	if ( $$specs{'sides_the_same'} eq 'Y' ) {
		$back_colours = $front_colours;
		$back_coatings = $front_coatings;
		$back_pms = $front_pms;
		$coatings .= ' back the same as front';
		$colorsidetwo = $colorsideone;
	} else {
		$side = 'SideTwo';
		foreach my $colour ( 'Cyan','Magenta','Yellow','Black' ) {
			if ( $$specs{'chk'.$colour.$side} ) {
				$back_colours += 1;
				if ( $colorsidetwo ){
					$colorsidetwo .= ' ';
				}
				$colorsidetwo .= $colour;
			} # end if
		} # end foreach

		if ( $$specs{'chkProcessColour'.$side} ) {
			$back_colours += 4;
		} # end if
		foreach my $k ( keys %$specs ) {
			if ( my ( $index ) = $k =~ /^chkColourCoating(\d+)$side/ ) {
				next if ! $$specs{"chkColourCoating$index$side"};
				my $type = $$specs{"ColourCoatingType$index$side"};
				next if ! $type;
				next if $$specs{"chkColourCoatingColour$index$side"} eq 'None';

				if ( $type =~ /Aqueous/ or $type =~ /Varnish/ or $type =~ /UV/ ) {
#Changes made on june-19-2008
#						$back_coatings .= '+'.$$specs{"ColourCoatingColour$index$side"};
					$back_coatings .= '+'.$$specs{"ColourCoatingType$index$side"};
				} elsif ( $type =~ /PMS/i ) {
					$back_pms += 1;
				} elsif ( $type =~ /Metallic/i ) {
					$back_coatings .= '+Metallic' if ! ($back_coatings =~ /Metallic/);
				} else {
					$back_coatings .= '+'.$$specs{"ColourCoatingType$index$side"};		#line added to show other types june-18-2008
						$back_colours += 1;
				} # end if
			} # end if
		} # end foreach
	} # end if
	return sprintf( '%s%s%s%s/%s%s%s%s %s',
			($front_colours ? $front_colours : ''),
			$colorsideone,
			($front_pms ? '+'.$front_pms.'PMS' : ''),
			$front_coatings,
			( $back_colours ? $back_colours : '' ),
			$colorsidetwo,
			($back_pms ? '+'.$back_pms.'PMS' : ''),
			$back_coatings,
			$coatings,
			);

} # end sub get_colour_description

1;

__END__
