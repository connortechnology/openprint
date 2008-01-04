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
my $debug = 1;
my $master_time;

use strict;
use POSIX qw(ceil);

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
require openprint::Estimating::UVCoating;
require openprint::Equipment;
require openprint::Material;
#use Time::HiRes qw{ time gettimeofday tv_interval }; 


# These are use to tell the code which variables to save
# There are other values in teh actual specs hash, but htey are either transitory or should never be changed
my %variables = (
		'txtSignatureType' => ['save'],
		'txtServiceDescription'	=> ['save'],
		'txtPrice1' => ['save','output'],
		'txtPrice2' => ['save','output'],
		'txtPrice3' => ['save','output'],
		'MPrice1' => ['save','output'],
		'MPrice2' => ['save','output'],
		'MPrice3' => ['save','output'],
		'chkCyanSideOne' => ['save'],
		'chkMagentaSideOne' => ['save'],
		'chkYellowSideOne'	=> ['save'],
		'chkBlackSideOne' 	=> ['save'],
		'chkProcessColourSideOne' => ['save'],
		'CyanSpotSideOneCoverage'		=>	['save'],
		'MagentaSpotSideOneCoverage'	=>	['save'],
		'YellowSpotSideOneCoverage'		=>	['save'],
		'BlackSpotSideOneCoverage'		=>	['save'],

		'CyanSideOneCoverage'	=>	['save'],
		'MagentaSideOneCoverage'	=>	['save'],
		'YellowSideOneCoverage'	=>	['save'],
		'BlackSideOneCoverage'	=>	['save'],

		'CyanSpotSideTwoCoverage'	=>	['save'],
		'MagentaSpotSideTwoCoverage'	=>	['save'],
		'YellowSpotSideTwoCoverage'	=>	['save'],
		'BlackSpotSideTwoCoverage'	=>	['save'],

		'CyanSideTwoCoverage'	=>	['save'],
		'MagentaSideTwoCoverage'	=>	['save'],
		'YellowSideTwoCoverage'	=>	['save'],
		'BlackSideTwoCoverage'	=>	['save'],

		'chkSpecialSideOneColour1' => ['save'], 'txtSpecialSideOneColour1' => ['save'], 'txtSpecialSideOneColourInkPercent1' => ['save'],
		'chkSpecialSideOneColour2' => ['save'], 'txtSpecialSideOneColour2' => ['save'], 'txtSpecialSideOneColourInkPercent2' => ['save'],
		'chkSpecialSideOneColour3' => ['save'], 'txtSpecialSideOneColour3' => ['save'], 'txtSpecialSideOneColourInkPercent3' => ['save'],
		'chkSpecialSideOneColour4' => ['save'], 'txtSpecialSideOneColour4' => ['save'], 'txtSpecialSideOneColourInkPercent4' => ['save'],
		'chkSpecialSideOneColour5' => ['save'], 'txtSpecialSideOneColour5' => ['save'], 'txtSpecialSideOneColourInkPercent5' => ['save'],
		'chkSpecialSideOneColour6' => ['save'], 'txtSpecialSideOneColour6' => ['save'], 'txtSpecialSideOneColourInkPercent6' => ['save'],
		'chkSpecialSideOneColour7' => ['save'], 'txtSpecialSideOneColour7' => ['save'], 'txtSpecialSideOneColourInkPercent7' => ['save'],
		'chkSpecialSideOneColour8' => ['save'], 'txtSpecialSideOneColour8' => ['save'], 'txtSpecialSideOneColourInkPercent8' => ['save'],
		'rdbAqueousSideOne' => ['save'],
		'chkVarnishSpotGlossSideOne' => ['save'],'chkVarnishSpotMatteSideOne' => ['save'],'chkVarnishOverallGlossSideOne' => ['save'],'chkVarnishOverallMatteSideOne' => ['save'],'chkVarnishDryTrapSideOne' => ['save'],
		'VarnishSpotGlossSideOneCoverage'=> ['save'],
		'VarnishSpotMatteSideOneCoverage'=> ['save'],
		'SideOneUVCoatingType'=>['save'],
		'chkCyanSideTwo' => ['save'],'chkMagentaSideTwo' => ['save'],'chkYellowSideTwo' => ['save'],'chkBlackSideTwo' => ['save'],
		'chkProcessColourSideTwo' => ['save'],
		'chkSpecialSideTwoColour1' => ['save'], 'txtSpecialSideTwoColour1' => ['save'], 'txtSpecialSideTwoColourInkPercent1' => ['save'],
		'chkSpecialSideTwoColour2' => ['save'], 'txtSpecialSideTwoColour2' => ['save'], 'txtSpecialSideTwoColourInkPercent2' => ['save'],
		'chkSpecialSideTwoColour3' => ['save'], 'txtSpecialSideTwoColour3' => ['save'], 'txtSpecialSideTwoColourInkPercent3' => ['save'],
		'chkSpecialSideTwoColour4' => ['save'], 'txtSpecialSideTwoColour4' => ['save'], 'txtSpecialSideTwoColourInkPercent4' => ['save'],
		'chkSpecialSideTwoColour5' => ['save'], 'txtSpecialSideTwoColour5' => ['save'], 'txtSpecialSideTwoColourInkPercent5' => ['save'],
		'chkSpecialSideTwoColour6' => ['save'], 'txtSpecialSideTwoColour6' => ['save'], 'txtSpecialSideTwoColourInkPercent6' => ['save'],
		'chkSpecialSideTwoColour7' => ['save'], 'txtSpecialSideTwoColour7' => ['save'], 'txtSpecialSideTwoColourInkPercent7' => ['save'],
		'chkSpecialSideTwoColour8' => ['save'], 'txtSpecialSideTwoColour8' => ['save'], 'txtSpecialSideTwoColourInkPercent8' => ['save'],
		'rdbAqueousSideTwo' => ['save'],
		'chkVarnishSpotGlossSideTwo' => ['save'],'chkVarnishSpotMatteSideTwo' => ['save'],'chkVarnishOverallGlossSideTwo' => ['save'],'chkVarnishOverallMatteSideTwo' => ['save'],'chkVarnishDryTrapSideTwo' => ['save'],
		'VarnishSpotGlossSideTwoCoverage'=> ['save'],
		'VarnishSpotMatteSideTwoCoverage'=> ['save'],
		'SideTwoUVCoatingType'=>['save'],
		'chkBleedLeft' => ['save'],'chkBleedRight' => ['save'],'chkBleedTop' => ['save'],'chkBleedBottom' => ['save'],
		'ddmBleedSize1' => ['save','output'], 'ddmBleedSize2' => ['save','output'], 'ddmBleedSize3' => ['save','output'],
		'chkOverrideBleedSize1'=>['save'], 'chkOverrideBleedSize2'=>['save'], 'chkOverrideBleedSize3'=>['save'],

		'BleedSize' => ['save','output'], 'BleedLeft' => ['save'], 'BleedRight' => ['save'], 'BleedTop' => ['save'], 'BleedBottom' => ['save'],
		'rdbColourBar' => ['save','output'], 'txtCropMarkSpace' => ['save'],
		'ddmStockBrand' => ['save'], 'txtSpecificStockBrand' => ['save'], 'ddmStockFinish' => ['save'], 'txtSpecificStockFinish' => ['save'], 'ddmStockColour' => ['save'], 'txtSpecificStockColour' => ['save'],

		'ddmStockWeight' => ['save'], 'txtSpecificStockWeight'=>['save'],
		'txtSpecificStockCalliper' => ['save','output'], 'txtSpecificStockWidth' => ['save'], 'txtSpecificStockHeight' => ['save'], 'CustomSheetDoubleSided' => ['save'], 'CustomStockPrice' => ['save'],'txtCustomMWeight' => ['save'],'txtStockGSM' => ['save','output'],
		'basis_width'=>['save'],'basis_height'=>['save'],'basis_mweight'=>['save'],
		'StockGrade'	=> ['save'],	
		'CustomStockPriceUnits' => ['save'],
		'txtUnspecifiedPageQuantity1' => ['output'], 'PageQuantity1' => ['save','output'],
		'txtUnspecifiedPageQuantity2' => ['output'], 'PageQuantity2' => ['save','output'],
		'txtUnspecifiedPageQuantity3' => ['output'], 'PageQuantity3' => ['save','output'],
		'chkOverridePageQuantity1' => ['save'], 'chkOverridePageQuantity2' => ['save'], 'chkOverridePageQuantity3' => ['save'],
		'SpreadRows1' => ['save','output'],'SpreadCols1' => ['save','output'],
		'SpreadRows2' => ['save','output'],'SpreadCols2' => ['save','output'],
		'SpreadRows3' => ['save','output'],'SpreadCols3' => ['save','output'],
		'ddmStockSheetSize1' => ['save','output'], 'ddmStockSheetSize2' => ['save','output'], 'ddmStockSheetSize3' => ['save','output'],
		'ddmRunStyle1' => ['save','output'], 'ddmRunStyle2' => ['save','output'], 'ddmRunStyle3' => ['save','output'],
		'ddmPress1' => ['save','output'], 'ddmPress2' => ['save','output'], 'ddmPress3' => ['save','output'], 
		'PrintingType1' => ['save','output'], 'PrintingType2' => ['save','output'], 'PrintingType3' => ['save','output'], 
		'PrintingTypes' => [],
		'rdbPlateType1' => ['save','output'], 'rdbPlateType2' => ['save','output'], 'rdbPlateType3' => ['save','output'],
		'txtPlateQuantity1' => ['save','output'], 'txtPlateQuantity2' => ['save','output'], 'txtPlateQuantity3' => ['save','output'], 
		'BlankPlateQuantity1' => ['save','output'], 'BlankPlateQuantity2' => ['save','output'], 'BlankPlateQuantity3' => ['save','output'], 
		'PreviousPlates1' => [], 'PreviousPlates2' => [], 'PreviousPlates3' => [],
		'txtPlateChangeQuantity1' => ['save'], 'txtPlateChangeQuantity2' => ['save'], 'txtPlateChangeQuantity3' => ['save'], 
		'txtPressSheetQty1' => ['save','output'], 'txtPressSheetQty2' => ['save','output'], 'txtPressSheetQty3' => ['save','output'],
		'chkOverrideImposition1' => ['save'], 'chkOverrideImposition2' => ['save'], 'chkOverrideImposition3' => ['save'],
		'txtImposition1' => ['save','output'], 'txtImposition2' => ['save','output'], 'txtImposition3' => ['save','output'],
		'StitchingImposition1' => ['save','output'], 'StitchingImposition2' => ['save','output'], 'StitchingImposition3' => ['save','output'],
		'FoldingImposition1' => ['save','output'], 'FoldingImposition2' => ['save','output'], 'FoldingImposition3' => ['save','output'],
		'txtImageWidth1' => ['save','output'], 'txtImageWidth2' => ['save','output'], 'txtImageWidth3' => ['save','output'],
		'txtImageHeight1' => ['save','output'], 'txtImageHeight2' => ['save','output'], 'txtImageHeight3' => ['save','output'],
		'txtLayoutWidth1' => ['save','output'], 'txtLayoutWidth2' => ['save','output'], 'txtLayoutWidth3' => ['save','output'],
		'txtLayoutHeight1' => ['save','output'], 'txtLayoutHeight2' => ['save','output'], 'txtLayoutHeight3' => ['save','output'],
		'hdnImpositionRows1' => ['save','output'], 'hdnImpositionRows2' => ['save','output'], 'hdnImpositionRows3' => ['save','output'],
		'hdnImpositionColumns1' => ['save','output'], 'hdnImpositionColumns2' => ['save','output'], 'hdnImpositionColumns3' => ['save','output'],
		'hdnImpositionDutchRows1' => ['save','output'], 'hdnImpositionDutchRows2' => ['save','output'], 'hdnImpositionDutchRows3' => ['save','output'],
		'hdnImpositionDutchColumns1' => ['save','output'], 'hdnImpositionDutchColumns2' => ['save','output'], 'hdnImpositionDutchColumns3' => ['save','output'],
		'txtQuantity1' => ['save','output'], 'txtQuantity2' => ['save','output'], 'txtQuantity3' => ['save','output'], 
		'hdnImpressionQuantity1' => ['save','output'], 'hdnImpressionQuantity2' => ['save','output'], 'hdnImpressionQuantity3' => ['save','output'], 
		'rdbPressProof' => ['save'], 
		'txtMWeight1' => ['save','output'], 'txtMWeight2' => ['save','output'], 'txtMWeight3' => ['save','output'],
		'hdnSuppliedStockWidth1' => ['save','output'], 'hdnSuppliedStockWidth2' => ['save','output'], 'hdnSuppliedStockWidth3' => ['save','output'],
		'hdnSuppliedStockHeight1' => ['save','output'], 'hdnSuppliedStockHeight2' => ['save','output'], 'hdnSuppliedStockHeight3' => ['save','output'],
		'StockWidth1' => ['save','output'], 'StockWidth2' => ['save','output'], 'StockWidth3' => ['save','output'],
		'StockHeight1' => ['save','output'], 'StockHeight2' => ['save','output'], 'StockHeight3' => ['save','output'],
		'OverrideStockWidth1' => ['save'], 'OverrideStockWidth2' => ['save'], 'OverrideStockWidth3' => ['save'],
		'OverrideStockHeight1' => ['save'], 'OverrideStockHeight2' => ['save'], 'OverrideStockHeight3' => ['save'],
		'StockType' => ['save','output'],'StockType1' => ['save','output'], 'StockType2' => ['save','output'], 'StockType3' => ['save','output'],
		'hdnImageOrientation1' => ['save','output'], 'hdnImageOrientation2' => ['save','output'], 'hdnImageOrientation3' => ['save','output'], 
		'hdnNetSheetCount1' => ['save','output'], 'hdnNetSheetCount2' => ['save','output'], 'hdnNetSheetCount3' => ['save','output'],
		'SheetQuantity1' => ['save','output'], 'SheetQuantity2' => ['save','output'], 'SheetQuantity3' => ['save','output'],
		'RunTime1' => ['save','output'], 'RunTime2' => ['save','output'], 'RunTime3' => ['save','output'],
		'txtWidth' => ['save'], 'txtHeight' => ['save'], 'txtFinalWidth' => ['save'], 'txtFinalHeight' => ['save'],
		'chkOverrideDimensions'	=> ['save'],
		'txtFinishedCalliper' => ['save','output'], 
		'PageQuantity' => ['save'], # for Scratch Pads
# Presentation Folders
		'rdbPanels' => ['save'],'rdbPocketSize' => ['save'],'chkPocketLeft' => ['save'],'chkPocketCenter' => ['save'],'chkPocketRight' => ['save'],
		'rdbSuppliedStock' => ['save'], 'rdbSpecificStock' => ['save'],'rdbTemplateType' => ['save'],
		'chkOverrideRunStyle1' => ['save'], 'chkOverrideRunStyle2' => ['save'], 'chkOverrideRunStyle3' => ['save'],
		'chkOverrideSheetSize1' => ['save'], 'chkOverrideSheetSize2' => ['save'], 'chkOverrideSheetSize3' => ['save'],
		'chkOverridePress1' => ['save'], 'chkOverridePress2' => ['save'], 'chkOverridePress3' => ['save'],
		'chkOverridePrintingType1' => ['save'], 'chkOverridePrintingType2' => ['save'], 'chkOverridePrintingType3' => ['save'],
		'Versions' => ['save'],
		'ddmProjectSize' => ['save'],
		'ScreenType' => ['save'],
		'rdbGrainDirection1' => ['save','output'], 'rdbGrainDirection2' => ['save','output'], 'rdbGrainDirection3' => ['save','output'],
		'chkOverrideGrainDirection1' => ['save'], 'chkOverrideGrainDirection2' => ['save'], 'chkOverrideGrainDirection3' => ['save'],
		'txtPressSheetComboItems'=>['save'],
		'txtSpreadSize' => ['save'],
		'Group' => ['save'], 'GroupPageQuantity' => ['save'],
		);

sub variables {
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k if sets::isin( 'save', $variables{$k} );
	} # end foreach;
	return @v;
}

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
	foreach my $ssid ( $Project->signatures( $$specs{'txtSignatureType'} ) ) {
		next if $service_index and ( $ssid >= $service_index );
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ssid );
$openprint::log->debug("Group: $$sig_specs{'Group'} != $$specs{'Group'}");
		next if $$sig_specs{'Group'} != $$specs{'Group'};
		$specified_pages += $$sig_specs{"PageQuantity$qty_index"};
	} # end foreach

$openprint::log->debug("Unspec: $$specs{'GroupPageQuantity'} - $specified_pages = " . ($$specs{'GroupPageQuantity'} - $specified_pages) );
	return $$specs{'GroupPageQuantity'} - $specified_pages;
} # end sub get_unspecified_pages

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

	foreach my $index ( 1 .. 8 ) {
		if ( $$specs{'chkSpecial'.$side.'Colour'.$index.$signature} ) {
			if ( ! $$specs{'txtSpecial'.$side.'Colour'.$index.$signature} ) {
				$$specs{'txtSpecial'.$side.'Colour'.$index.$signature} = "PMS $index";
				$$v{'txtSpecial'.$side.'Colour'.$index.$signature} = [ sets::union( 'output', @{$$v{'txtSpecial'.$side.'Colour'.$index.$signature}} ) ];
			} # end if
			push @colours, $$specs{'txtSpecial'.$side.'Colour'.$index.$signature};
		} else {
			$$specs{'txtSpecial'.$side.'Colour'.$index.$signature} = '';
			$$v{'txtSpecial'.$side.'Colour'.$index.$signature} = [ sets::union( 'output', @{$$v{'txtSpecial'.$side.'Colour'.$index.$signature}} ) ];
		} # end if
	} # end foreach

	if ( $$specs{'chkVarnishOverallGloss'.$side.$signature} ) {
		push @colours, 'Overall Varnish Gloss';
	} # end if
	if ( $$specs{'chkVarnishOverallMatte'.$side.$signature} ) {
		push @colours, 'Overall Varnish Matte';
	} # end if
	if ( $$specs{'chkVarnishSpotGloss'.$side.$signature} ) {
		push @colours, 'Spot Varnish Gloss';
	} # end if
	if ( $$specs{'chkVarnishSpotMatte'.$side.$signature} ) {
		push @colours, 'Spot Varnish Matte';
	} # end if
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
#} else {
#$$v{$colour.'Spot'.$side.'Coverage'.$signature} = [ sets::exclude( ['output'], $$v{$colour.'Spot'.$side.'Coverage'.$signature} ) ];
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
		foreach my $index ( 1 .. 8 ) {
			if ( $$specs{'chkSpecial'.$side.'Colour'.$index.$signature} ) {
				if ( ! int($$specs{'txtSpecial'.$side.'ColourInkPercent'.$index.$signature}) ) {
					$$specs{'txtSpecial'.$side.'ColourInkPercent'.$index.$signature} = $openprint::config{'DefaultInkCoverage'};
					$$v{'txtSpecial'.$side.'ColourInkPercent'.$index.$signature} = [ sets::union( 'output', @{$$v{'txtSpecial'.$side.'ColourInkPercent'.$index.$signature}} ) ];
				} # end if
				$$specs{'txtSpecial'.$side.'ColourInkPercent'.$index.$signature} =~ s/[^\d\.]//g;
				$inkCoverage{$$specs{'txtSpecial'.$side.'Colour'.$index.$signature}} += $$specs{'txtSpecial'.$side.'ColourInkPercent'.$index.$signature};
			} else {	
				$$specs{'txtSpecial'.$side.'ColourInkPercent'.$index.$signature} = '';
			} # end if
		} # end foreach
		foreach my $type ( 'Gloss','Matte' ) {
			if ( $$specs{'chkVarnishSpot'.$type.$side.$signature} ) {
				if ( ! $$specs{'VarnishSpot'.$type.$side.'Coverage'.$signature} ) {
					$$specs{'VarnishSpot'.$type.$side.'Coverage'.$signature} = $openprint::config{'DefaultInkCoverage'};
					$$v{'VarnishSpot'.$type.$side.'Coverage'.$signature} = [ sets::union( 'output', @{$$v{'VarnishSpot'.$type.$side.'Coverage'.$signature}} ) ];
				} else {
					$$v{'VarnishSpot'.$type.$side.'Coverage'.$signature} = [ sets::exclude( ['output'], $$v{'VarnishSpot'.$type.$side.'Coverage'.$signature} ) ];
				} # end if
				$$specs{'VarnishSpot'.$type.$side.'Coverage'.$signature} =~ s/[^\d\.]//g;
				$inkCoverage{$type.'Varnish'} += $$specs{'VarnishSpot'.$type.$side.'Coverage'.$signature};
			} # end if
		} # end foreach type
	} # end foreach Side
	return %inkCoverage;
} # end sub get_inkcoverage


sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;
#my $master_time = gettimeofday();

	if ( ! $project_index or ! $service_index ) {
		$log->debug("No Project Index ($project_index) or Service_index ($service_index)" );
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	$$specs{'Status'} = 'calculated';
	$$specs{'alert'} = '';

	if ( ( defined $$specs{'PageQuantity'} ) and $$specs{'PageQuantity'} =~ /[^\d\.]/ ) {
		$variables{'PageQuantity'} = [ sets::exclude( ['output'], $variables{'PageQuantity'} ) ];
		$$specs{'PageQuantity'} =~ s/[^\d\.]//g;
	} # end if

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	# First, clean up all inputs
	foreach my $qty_index ( 1 .. 3 ) {
		next if ! $Project->quantity($qty_index);
		
		foreach my $k ( 'txtPlateChangeQuantity' ) {
			if ( $$specs{$k.$qty_index} =~ /\D/ ) {
				$variables{$k.$qty_index} = [ sets::union( 'output', @{$variables{$k.$qty_index}} ) ];
				$$specs{$k.$qty_index} =~ s/\D//g;
			} else {
				$variables{$k.$qty_index} = [ sets::exclude( ['output'], $variables{$k.$qty_index} ) ];
			} # end if
		} # end foreach
	} # end foreach


	if ( $$specs{'ProjectType'} eq 'PresentationFolders' ) {
		if ( ! ( $$specs{'rdbPanels'} or $$specs{'txtFinalWidth'} or $$specs{'txtFinalHeight'} or $$specs{'rdbPocketSize'} ) ) {
			return $$specs{'Status'} = 'uncalculated';
		} elsif ( ! ( $$specs{'chkPocketCenter'} or $$specs{'chkPocketLeft'} or $$specs{'chkPocketRight'} ) ) {
			$$specs{'alert'} .= 'Please select where you would the pockets.';
			return $$specs{'Status'} = 'uncalculated';
		} # end if

		if ( $$specs{'ddmProjectSize'} ne 'Custom' ) {
#$log->debug("Auto calc dimensions");
# auto calc flat dimensions
			$$specs{'txtWidth'} = $$specs{'txtFinalWidth'} * $$specs{'rdbPanels'};
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
			$$specs{'txtHeight'} = $$specs{'txtFinalHeight'} + $$specs{'rdbPocketSize'};
			$variables{'txtWidth'} = [ sets::exclude( ['output'], $variables{'txtWidth'} ) ];
			$variables{'txtHeight'} = [ sets::exclude( ['output'], $variables{'txtHeight'} ) ];
			$variables{'rdbTemplateType'} = [ sets::exclude( ['output'], $variables{'rdbTemplateType'} ) ];
		} # end if
	} # end if
	my $printing_specs = openprint::service::get_specs_ref( $project_index, $$services{''}[0] );
	if ( $$specs{'txtSignatureType'} ) {
		if ( ! $$printing_specs{'txtSpreadSize'} ) {
			$openprint::log->warn('No Spread Size!');
			$$printing_specs{'txtSpreadSize'} = 4;
		} # end if

		if ( $$specs{'txtSignatureType'} eq 'GateFolded Spreads' ) {
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
		} elsif ( $$specs{'txtSignatureType'} eq 'Cover Pages' and $$printing_specs{'rdbTemplateType'} eq 'PerfectBound' ) {
#$$specs{'txtSpreadSize'} = $printing_specs{'txtSpreadSize'};
#$variables{'txtSpreadSize'} = [ sets::union( 'output', @{$variables{'txtSpreadSize'}} ) ];
			if ( $$specs{'chkOverrideDimensions'} ne 'Y' ) {
# Perfect bound requires more width on th cover to conver the calliiper	
				my $finished_calliper = 0;
				$_ = q{SELECT lngServiceIndex FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND strName='txtSignatureType' AND NOT strValue='Cover Pages'};
				my @signature_service_indices = sql::execute( $log, $dbh, $_, $project_index );
				foreach my $signature_service_index ( @signature_service_indices ) {
					my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );

					my $calliper1 = $$sig_specs{'PageQuantity1'} ? $$sig_specs{'PageQuantity1'} * $$sig_specs{'txtSpecificStockCalliper'} : $$sig_specs{'txtSpecificStockCalliper'};
					my $calliper2 = $$sig_specs{'PageQuantity2'} ? $$sig_specs{'PageQuantity2'} * $$sig_specs{'txtSpecificStockCalliper'} : $$sig_specs{'txtSpecificStockCalliper'};
					my $calliper3 = $$sig_specs{'PageQuantity3'} ? $$sig_specs{'PageQuantity3'} * $$sig_specs{'txtSpecificStockCalliper'} : $$sig_specs{'txtSpecificStockCalliper'};
					if ( $calliper1 ) {
						$finished_calliper += $calliper1/2;
					} elsif ( $calliper2 ) {
						$finished_calliper += $calliper2/2;
					} elsif ( $calliper3 ) {
						$finished_calliper += $calliper3/2;
					} # end if
				} # end foreach signature

				$$specs{'txtWidth'} = $$printing_specs{'txtFinalWidth'}*2 + $finished_calliper;
				$variables{'txtWidth'} = [ sets::union( 'output', @{$variables{'txtWidth'}} ) ];
				if ( ! $$specs{'txtHeight'} ) {
					$$specs{'txtHeight'} = $$printing_specs{'txtHeight'};
					$variables{'txtHeight'} = [ sets::union( 'output', @{$variables{'txtHeight'}} ) ];
				} else {
					$variables{'txtHeight'} = [ sets::exclude( ['output'], $variables{'txtHeight'} ) ];
				} # end if
$openprint::log->debug("Cover size calc: $finished_calliper");
			} else {
				$variables{'txtWidth'} = [ sets::exclude( ['output'], $variables{'txtWidth'} ) ];
				$variables{'txtHeight'} = [ sets::exclude( ['output'], $variables{'txtHeight'} ) ];
			} # end if
		} else {
# if it's a book signature, then auto-populate the width and height
			$$specs{'txtSpreadSize'} = $$printing_specs{'txtSpreadSize'};
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
				} # end if
			} # end if
		} # end if Spread Type
	} else { # not a book
# If no spreadsize, then we are likely not a book, and the spread size is 2
		$$specs{'txtSpreadSize'} = 2 if ! $$specs{'txtSpreadSize'};
		$variables{'txtWidth'} = [ sets::exclude( ['output'], $variables{'txtWidth'} ) ];
		$variables{'txtHeight'} = [ sets::exclude( ['output'], $variables{'txtHeight'} ) ];
	} # end if

	if ( ! ( $$specs{'txtWidth'} and $$specs{'txtHeight'} ) ) {
		$$specs{'alert'} .= "Please enter Width and Height<br/>";
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my @side_one_colours = get_colours( $specs, 'SideOne' );
	my @side_two_colours = get_colours( $specs, 'SideTwo' );
$openprint::log->debug("# of colours: " . @side_one_colours );
	my %inkCoverage = get_inkcoverage( $specs );
	if ( $$specs{'ProjectType'} eq 'ScratchPads' ) {
		if ( ! $$specs{'PageQuantity'} ) {
			$$specs{'alert'} .= 'Please enter the # of pages per pad.';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
	} elsif ( $$specs{'ProjectType'} eq 'PressSheetCombination' ) {
		@$specs{'txtFinalWidth','txtFinalHeight'} = @$specs{'txtWidth','txtHeight'};
	} # end if

	if ( ! ( @side_one_colours or @side_two_colours ) ) {
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
		if ( ! $$specs{'CustomStockPriceUnits'} ) {
			$$specs{'alert'} .= 'Please select the units for the stock price';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
		if ( ( ! $$specs{'StockGrade'} ) and $$specs{'txtSpecificStockFinish'} ) {
			if ( $$specs{'txtSpecificStockFinish'} =~ /gloss/i ) {
				$$specs{'StockGrade'} = 1;
			} elsif ( $$specs{'txtSpecificStockFinish'} =~ /matte/i ) {
				$$specs{'StockGrade'} = 2;
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
		my $Paper = new openprint::Paper();
		@$Paper{'cuttable','perfecting','calliper','doublesided','gsm','grade'} = ( 'Y',($$specs{'txtSpecificStockBrand'} =~ /offset/i ? 'Y' : 'N'),@$specs{'txtSpecificStockCalliper','CustomSheetDoubleSided','txtStockGSM','StockGrade'});
		@$Paper{'width','height','mweight','Price','type','Units','basis_width','basis_height','basis_mweight'} = @$specs{'txtSpecificStockWidth','txtSpecificStockHeight','txtCustomMWeight','CustomStockPrice','StockType','CustomStockPriceUnits','basis_width','basis_height','basis_mweight'};
		if ( $$specs{'StockType'} eq 'Roll' ) {
			delete $$Paper{'height'};
		} # end if
		$Paper->score_required( $Paper->calliper() > 0.008 );
		push @Papers, $Paper;
		@$Paper{'start_width','start_height'} = @$Paper{'width','height'};
		foreach my $k ( 'txtSpecificStockCalliper', 'txtSpecificStockWidth','txtSpecificStockHeight','txtCustomMWeight','txtCustomStockPrice', 'txtStockGSM','CustomStockPriceUnits','basis_mweight' ) {
			$variables{$k} = [ sets::exclude( ['output'], $variables{$k} ) ];
		} # end foreach
		if ( ( ! $$specs{'txtCustomMWeight'} and $Paper->gsm() ) ) {
			$variables{'txtCustomMWeight'} = [ sets::union( 'output', @{$variables{'txtCustomMWeight'}} ) ];
			$$specs{'txtCustomMWeight'} = $Paper->mweight();
		} 
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
				'project_type_id'=>$Project->type()->id(),
				);
# Load this here, so that later cloning will copy the prices as well.
		foreach my $P ( @Papers ) {
			$P->prices();
		} # end foreach
		$$specs{'txtSpecificStockCalliper'} = $Papers[0]->calliper() if @Papers;
		foreach my $k ( 'txtSpecificStockCalliper', 'txtSpecificStockWidth','txtSpecificStockHeight','txtCustomMWeight','txtCustomStockPrice', 'txtStockGSM','CustomStockPriceUnits' ) {
			$variables{$k} = [ sets::union( 'output', @{$variables{$k}} ) ];
		} # end foreach
	} # end if
	if ( ! @Papers ) {
		$$specs{'alert'} .= 'There was a problem loading the specified paper.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	# If Stock size is overridden, check the list of stocks to see if the specified on is in the list.  If it isn't, then add duplicates, cut to size
	
	foreach my $qty_index ( 1 .. 3 ) {
		next if ! $Project->quantity( $qty_index );

		if ( $$specs{'chkOverrideSheetSize'.$qty_index} eq 'Y' ) {
			if ( ! ( $$specs{'OverrideStockWidth'.$qty_index} or $$specs{'OverrideStockHeight'.$qty_index} ) ) {
				@$specs{'OverrideStockWidth'.$qty_index, 'OverrideStockHeight'.$qty_index} = split 'x', $$specs{'ddmStockSheetSize'.$qty_index};
			} # end if
			my $found = 0;
			my @Ps = @Papers;
			@Papers = ();
			
			foreach my $P ( @Ps ) {
				if ( $P->width() == $$specs{'OverrideStockWidth'.$qty_index } and $P->height() == $$specs{'OverrideStockHeight'.$qty_index} ) {
					$found = 1;
					push @Papers, $P;
				} # end if
			} # end foreach

			if ( ! $found ) {
				foreach my $P ( @Ps ) {
					# Don't cut rolls into sheets
					next if ! $P->cuttable();
					if ( $P->type() eq 'Roll' ) {
						next if $$specs{'OverrideStockHeight'.$qty_index};
						#next if $P->start_width() and ($P->start_width() < $$specs{'OverrideStockWidth'.$qty_index });
					} elsif ( $P->type() eq 'Sheet' ) {
						# Don't cut sheets into rolls
						next if ! $$specs{'OverrideStockHeight'.$qty_index };
						# Must be big enough to cut
						next if ( $P->start_width() < $$specs{'OverrideStockWidth'.$qty_index } or $P->start_height() < $$specs{'OverrideStockHeight'.$qty_index } ) and ( $P->start_width() < $$specs{'OverrideStockHeight'.$qty_index } or $P->start_height() < $$specs{'OverrideStockWidth'.$qty_index } );
					} # end if
					my $P2 = $P->clone();

					# Make sure gsm has calculated
					$P2->gsm();
					$P2->width( $$specs{'OverrideStockWidth'.$qty_index } );
					$P2->height( $$specs{'OverrideStockHeight'.$qty_index } );
					if ( $P2->type() ne 'Roll' ) {
						$P2->mweight( 0 );
					} else {
						$P2->start_width( $$specs{'OverrideStockWidth'.$qty_index } );
					} # end if
					push @Papers, $P2;
				} # end foreach paper
			} # end if found
		} # end if override
	} # end foreach qty_index

	if ( ! @Papers ) {
		$$specs{'alert'} .= 'There was a problem loading the specified paper.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my %project = (
			'Add Grip Width',	$$specs{'GripWidth'},
			'Add Grip Height',	$$specs{'GripHeight'},
			'Add Colour Bar',	$$specs{'rdbColourBar'},
			'image_width',		$$specs{'txtWidth'},
			'image_height',		$$specs{'txtHeight'},
			'BleedLocations',	join(',', @$specs{'chkBleedBottom','chkBleedTop','chkBleedLeft','chkBleedRight'}),
			'Calliper',			$$specs{'txtSpecificStockCalliper'},
			'CropMarkSpace',	$$specs{'txtCropMarkSpace'},
			);
# Paper is now an array ref

	$project{'Binding'} = openprint::print::get_book_type( $Project );
	if ( ! $$services{'NoBindery'} ) {
		if ( $$services{'DieCutting'} ) {
			$project{'NeedFolding'} = 0;
			$project{'NeedScoring'} = 0;
		} else {	
			$project{'NeedFolding'} = openprint::Estimating::Folding::signature_needs( $specs );
			$project{'NeedScoring'} = openprint::Estimating::Scoring::signature_needs( $Project, $specs );
		} # end if

		$project{'NeedCutting'} = openprint::Estimating::Cutting::signature_needs( $Project, $specs );
	} else {
		$project{'NeedScoring'} = 0;
		$project{'NeedFolding'} = 0;
		$project{'NeedCutting'} = 0;
	} # end if
	$project{'HasFolding'} = $$services{'Folding'} ? $$services{'Folding'}[0] : 0;
	$project{'HasScoring'} = $$services{'Scoring'} ? $$services{'Scoring'}[0] : 0;
	$project{'HasPerforating'} = $$services{'Perforating'} ? $$services{'Perforating'}[0] : 0;
	$project{'HasDieCutting'} = $$services{'DieCutting'} ? $$services{'DieCutting'}[0] : 0;
	$project{'HasCutting'} = $$services{'Cutting'} ? $$services{'Cutting'}[0] : 0;
	@$specs{'HasFolding','HasCutting','HasScoring'} = @project{'HasFolding','HasCutting','HasScoring'};
	@$specs{'NeedFolding','NeedCutting','NeedScoring'} = @project{'NeedFolding','NeedCutting','NeedScoring'};

	# Need UVCoating
	if ( 
			($$specs{'SideOneUVCoatingType'} and ($$specs{'SideOneUVCoatingType'} ne 'None' )) or
			($$specs{'SideTwoUVCoatingType'} and ($$specs{'SideTwoUVCoatingType'} ne 'None' )) ) {
		$project{'NeedUVCoating'} = 1;
		if ( ! $$services{'UVCoating'} ) {
			push @{$$services{'UVCoating'}}, openprint::print_project::insert_service( $log, $dbh, $project_index, 'UVCoating' );
		} # end if	
		$project{'HasUVCoating'} = $$services{'UVCoating'}[0];
	} # end if

# Do this once now, so we don't do it many times in calc_print_price
	my @filtered_colours = filter_colours( @side_one_colours, @side_two_colours );

	my @possible_presses = sort { $a->strid() <=> $b->strid() } select_presses( $project_index, $Papers[0], $specs, \@side_one_colours, \@side_two_colours );
	if ( ! @possible_presses ) {
		$$specs{'alert'} = 'There were no possible presses. Your project may be too large for us.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} elsif ( $debug ) {
		$openprint::log->debug( "Presses: " . join(',', map { $_->strid() } @possible_presses ) );
	} # end if

# Caches
	my %mixed_colours;
	my %washed_colours;

	foreach my $index ( $Project->signatures() ) {
		next if $index >= $service_index;
		my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
		foreach my $colour ( get_colours( $sig_specs, 'SideOne' ), get_colours( $sig_specs, 'SideTwo' ) ) {
			$mixed_colours{$colour} = 1;
			foreach my $qty_index ( 1 ..3 ) {
				$washed_colours{$colour.'-'.$$sig_specs{'ddmPress'.$qty_index}.'-'.$qty_index} = 1;
			} # end foreach
		} # end foreach
	} # end for each

	my $s = $openprint::dbh->selectall_arrayref(q{SELECT * FROM Inks}, { Slice => {} } );
	my %special_colours = map { $_->{pmsid}, $_ } @$s;

	%{$project{'FoldingSpecs'}} = %{openprint::service::get_specs_ref( $Project, $project{'HasFolding'} )} if $project{'HasFolding'};
	%{$project{'CuttingSpecs'}} = %{openprint::service::get_specs_ref( $Project, $project{'HasCutting'} )} if $project{'HasCutting'};
	%{$project{'ScoringSpecs'}} = %{openprint::service::get_specs_ref( $Project, $project{'HasScoring'} )} if $project{'HasScoring'};
	%{$project{'PerforatingSpecs'}} = %{openprint::service::get_specs_ref( $Project, $project{'HasPerforating'} )} if $project{'HasPerforating'};
	%{$project{'StitchingSpecs'}} = %{openprint::service::get_specs_ref( $Project, $$services{'SaddleStitching'}[0] )} if $$services{'SaddleStitching'};

	if ( $$services{'UVCoating'} ) {
$openprint::log->debug("Grabbing UV Specs");
		%{$project{'UVCoatingSpecs'}} = %{openprint::service::get_specs_ref( $Project, $$services{'UVCoating'}[0] )};
		$project{'UVCoatingSpecs'}{'SideOneCoatingType-'.$$specs{SignatureIndex}} = $$specs{'SideOneUVCoatingType'};
		$project{'UVCoatingSpecs'}{'SideTwoCoatingType-'.$$specs{SignatureIndex}} = $$specs{'SideTwoUVCoatingType'};
	} # end if

#$openprint::log->debug("Master time before qty: " . ( sprintf('%.4f', tv_interval( [$master_time])*1000) ) .' usecs' );
	my %threads;
	my %prices;

	my @blah = ( 1 .. 3 );

	foreach my $qty_index ( reverse @blah ) {
$openprint::log->debug("QTY: $qty_index");
		$$specs{"txtPrice$qty_index"} = 0;
		my $qty = $Project->quantity($qty_index);
		next if ! defined $qty;
		next if ! int $qty;

		$$specs{'hdnBreakdown'.$qty_index} = "QTY: $qty: ";
		$qty *= $$specs{'PageQuantity'} if $$specs{'PageQuantity'};
		$qty *= $$specs{'txtNameQuantity'} if $$specs{'txtNameQuantity'};

		$$specs{'totalSpreads'} = 1;
# Figure out how many spreads we need!
		if ( $$specs{'txtSignatureType'} ) {
			$$specs{'totalSpreads'} = $$specs{'GroupPageQuantity'};
			$$specs{'txtUnspecifiedPageQuantity'.$qty_index} = get_unspecified_pages( $Project, $service_index, $printing_specs, $specs, $qty_index );
			$$specs{'txtUnspecifiedPageQuantity'.$qty_index} = 0 if $$specs{'txtUnspecifiedPageQuantity'.$qty_index} < 0;
		} # end if

		if ( $$printing_specs{'PrintingType'} ) {
			$$specs{'PrintingTypes'} = [ $$printing_specs{'PrintingType'} ];
		} else {

			if ( $$specs{'txtSignatureType'} eq 'Cover Pages' ) {
# FIgure out printing types
				foreach my $index ( $Project->signatures('Interior Pages') ) {
					my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
					if ( $$sig_specs{'PrintingType'.$qty_index} eq 'Digital' ) {
						$$specs{'PrintingTypes'} = ['Digital'];
					} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Waterless' ) {
						$$specs{'PrintingTypes'} = [ 'Waterless', 'Offset' ];
					} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Offset' ) {
						$$specs{'PrintingTypes'} = ['Offset','Waterless'];
					} else {
						$openprint::log->warn("Unknown printing type: " . $$sig_specs{'PrintingType'.$qty_index} );
					} # end if
					last if $$specs{'PrintingTypes'};
				} # end foreach

			} elsif ( $$specs{'txtSignatureType'} eq 'Interior Pages' ) {
# if the cover is digital, then we need digital
# if another interior spread is digital, then we need digital
# if the cover is offset, then we need offset
# if the cover is waterless, then we can do waterless, or offset
				my $cover_specs;
				foreach my $index ( $Project->signatures('Cover Pages') ) {
					$cover_specs = openprint::service::get_specs_ref( $project_index, $index );
					last;
				} # end foreach
				if ( $$cover_specs{'PrintingType'.$qty_index} eq 'Digital' ) {
					$$specs{'PrintingTypes'} = ['Digital'];
				} elsif ( $$cover_specs{'PrintingType'.$qty_index} eq 'Waterless' ) {
					$$specs{'PrintingTypes'} = [ 'Waterless', 'Offset' ];
				} elsif ( $$cover_specs{'PrintingType'.$qty_index} eq 'Offset' ) {
					$$specs{'PrintingTypes'} = ['Offset'];
				} # end if
				if ( ! $$specs{'PrintingTypes'} ) {

					foreach my $index ( $Project->signatures('Interior Pages') ) {
						next if $index == $service_index;
						my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
						if ( $$sig_specs{'PrintingType'.$qty_index} eq 'Digital' ) {
							$$specs{'PrintingTypes'} = ['Digital'];
						} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Waterless' ) {
							$$specs{'PrintingTypes'} = [ 'Waterless', 'Offset' ];
						} elsif ( $$sig_specs{'PrintingType'.$qty_index} eq 'Offset' ) {
							$$specs{'PrintingTypes'} = ['Offset'];
						} # end if
						last if $$specs{'PrintingTypes'};
					} # end foreach
				} # end if PrintingTypes
			} # end if Spread Type
		} # end if printing_specs{'PrintingType'}

		$$specs{'PreviousPlates'.$qty_index} = 0;
		$$specs{'PreviousBlankPlates'.$qty_index} = 0;
		foreach my $index ( $Project->signatures() ) {
	# Get plates in each previous signature, so we can get qty discounts
			next if $service_index and ($index >= $service_index);
			my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
			$$specs{'PreviousPlates'.$qty_index} += $$sig_specs{'txtPlateQuantity'.$qty_index};
			$$specs{'PreviousBlankPlates'.$qty_index} += $$sig_specs{'BlankPlateQuantity'.$qty_index};
		} # end foreach $index

		$project{print_sides} = 1;
		if ( ( @side_two_colours > 0 ) and ( @side_one_colours > 0 ) ) {
			$project{print_sides} = 2;
		} # end if

		# indexed by press
		my %impositions;
		my $imposition_count = 0;

		if ( $$specs{'chkOverridePress'.$qty_index} eq 'Y' ) {
			$variables{'ddmPress'.$qty_index} = [ sets::exclude( ['output'], $variables{'ddmPress'.$qty_index} ) ];
			if ( ! $$specs{'ddmPress'.$qty_index} ) {
#$openprint::log->error("No overriden press!");
				$$specs{'alert'} .= 'Please specify the desired press.<br/>';
				return $$specs{'Status'} = 'uncalculated';
			} # end if

			if ( ! sets::intersection( map{ $_->id() } ( openprint::Equipment::find('strid'=>$$specs{'ddmPress'.$qty_index}), @possible_presses ) ) ) {
#$log->error( $$specs{'ddmPress'.$qty_index} . ' not in ' . join(',', @possible_presses ) );
				$$specs{'alert'} = 'The press that you have chosen is not appropriate for the project specs.';
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

		if ( $$specs{'txtSignatureType'} ) {
			if ( $$specs{'chkOverridePageQuantity'.$qty_index} eq 'Y' ) {
				$project{'SpreadLayout'} = $$specs{'PageQuantity'.$qty_index} / $$specs{'txtSpreadSize'};
			} else {
				$project{'SpreadLayout'} = $$specs{'txtUnspecifiedPageQuantity'.$qty_index} / $$specs{'txtSpreadSize'};
			} # end if
$openprint::log->debug("SpreadLayout : " . $project{'SpreadLayout'} );
		} else {
$openprint::log->debug("No spread layout for you!");
		} # end if

		if ( (exists $project{'SpreadLayout'}) and ! $project{'SpreadLayout'} ) {
			$$specs{"txtImposition$qty_index"} = '';
			$$specs{"ddmRunStyle$qty_index"} = '';
			$$specs{"PageQuantity$qty_index"} = 0;
			$$specs{'alert'} .= "No more pages need to be specified for quantity $qty_index.";
			next;
		} # end if

# add all the impositions for each press
		foreach my $Press ( $$specs{'chkOverridePress'.$qty_index} eq 'Y' ? openprint::Equipment::find('strid'=>$$specs{'ddmPress'.$qty_index} ) : @possible_presses ) {
# These should be cached by the underlying layer anyways
			if ( ( $Press->specification('Feed') eq 'Web' ) and $openprint::usergroup::groups_cache{'Web Estimating'} and ! openprint::usergroup::is_user_in( ['Web Estimating'], $openprint::session{'user_id'} ) ) {
$openprint::log->debug('No Web 4 U');
				next;
			} # end if

			$openprint::log->debug("Trying press " . $Press->strid()) if $debug;
			my $press_index = $Press->id();
			if ( $$specs{'chkOverridePrintingType'.$qty_index} eq 'Y' ) {
				if ( $Press->specification('Printing Type') ne $$specs{'PrintingType'.$qty_index} ) {
#$openprint::log->error("Press Printing Type ($press_specs{'Printing Type'}) is not the overriden type " . $$specs{'PrintingType'.$qty_index} );
					next;
				} # end if
			} else {
				if ( $$specs{'PrintingTypes'} and ! sets::isin( $Press->specification('Printing Type'), $$specs{'PrintingTypes'} ) ) {
					$openprint::log->error('Press ' . $Press->strid() . ' Printing Type ('.$Press->specification('Printing Type') . ') is not in PrintingTypes');
					next;
				} # end if
			} # end if
# If we have a plate type override, then make sure that this press can do it.
			if ( ( $$specs{'chkOverridePlateType'.$qty_index} eq 'Y' ) and ( $Press->specifcation('Plate Type') ne $$specs{'rdbPlateType'.$qty_index} ) ) {
				$openprint::log->error("Press Plate Type ");
				next;
			} # end if


# This perfecting stuff: default to on, turn off if press can't do it, or the job is single sided.
			my $do_perfecting = 1;
			if ( $Press->specification('Perfecting Press') ne 'Y' ) {
#$openprint::log->debug("** This Press Can't Perfect - Missing \'Perfecting Press\' = Y equipment spec ***") if $debug;
				$do_perfecting = 0;
			} elsif ( @side_one_colours > ($Press->specification('Number of Colours')/2) or @side_two_colours > ($Press->specification('Number of Colours')/2) ) {
#$openprint::log->debug("** This to many colours to  Perfect  ***") if $debug;
				$do_perfecting = 0;
			} elsif ( $project{print_sides} == 1 ) {
				$do_perfecting = 0;
#$openprint::log->debug("** One sided:  Perfect  ***") if $debug;
			} elsif ( $$specs{'txtSpecificStockCalliper'} > $Press->specification('Maximum Calliper Perfecting') ) {
				$do_perfecting = 0;
#$openprint::log->debug("** Too thick to:  Perfect  ***") if $debug;
			} # end if
			my $do_work_turn = $project{print_sides} == 2 ? 1 : 0;
			if ( $do_work_turn ) {
				if ( ! $Papers[0]->doublesided() ) {
#$openprint::log->debug("No W&T due to doublesided" . $$Papers[0]->name() );
					$do_work_turn = 0;
				} elsif ( @filtered_colours > $Press->specification('Number of Colours') and $Press->specification('Multipass', $Papers[0]->gsm() ) ne 'Y' ) {
#$openprint::log->debug("No W&T due to multipass" . $$Papers[0]->gsm() );
					$do_work_turn = 0;
				} # end if
			} # end fi

# not all of the presses have a gutter spec so we will continue to use Grip for Width and Height
			$project{'Grip'} = $Press->specification('Grip');
			$project{'Gutter'} = $Press->specification('Gutter');
			$project{'Orientation'} = $Press->specification('Orientation');
			if ( $$specs{'chkOverrideBleedSize'.$qty_index} eq 'Y' ) {
				$project{'BleedSize'} = 1*$$specs{'ddmBleedSize'.$qty_index};
				$variables{'ddmBleedSize'.$qty_index} = [ sets::exclude( ['output'], $variables{'ddmBleedSize'.$qty_index} ) ];
			} else {
				$project{'BleedSize'} = 1*$Press->specification('Default Bleed Size', 1*$$printing_specs{'txtTotalPageQuantity'} );
				$variables{'ddmBleedSize'.$qty_index} = [ sets::union( 'output', @{$variables{'ddmBleedSize'.$qty_index}} ) ];
			} # end if

			my @c = sets::exclude( ['Cyan','Magenta','Yellow','Black','Cyan Spot Colour','Magenta Spot Colour','Black Spot Colour','Yellow Spot Colour'], [ @side_one_colours, @side_two_colours ] );

			if ( ! $$specs{'rdbColourBar'} ) {
				if ( @c ) {
					$project{'Add Colour Bar'} = $Press->specification('Colour Bar Default');
				} else {
					$project{'Add Colour Bar'} = $Press->specification('Process Colour Bar Default');
				} # end if
			} # end if
			if ( $project{'Add Colour Bar'} eq 'Y' ) {
				if ( @c ) {
					$project{'colour_bar_size'} = $Press->specification('Colour Bar Size');
				} else {
					$project{'colour_bar_size'} = $Press->specification('Process Colour Bar Size');
					if ( !$project{'colour_bar_size'} ) {
						$project{'colour_bar_size'} = $Press->specification('Colour Bar Size');
					}
				} # end if
			} else {
				$project{'colour_bar_size'} = 0;
			} # end if
			$project{'Colour Bar Orientation'} = $Press->specification('Colour Bar Orientation');
			$project{'Perfecting Single Gutter Size'} = $Press->specification('Perfecting Single Gutter Size');
			$project{'Perfecting Double Gutter Size'} = $Press->specification('Perfecting Double Gutter Size');
			$project{'Maximum Image Area Length'} = $Press->specification('Maximum Image Area Length');
			$project{'Maximum Image Area Width'} = $Press->specification('Maximum Image Area Width');
			$project{'Runstyles'} = $Press->specification('Runstyles');
			$project{'Cut Off'} = $Press->specification('Cut Off');
			$project{'txtSpreadSize'} = $$specs{'txtSpreadSize'};

			my @impositions;
# Start with an arrayof papers... an overrided paper may or may not exist in the array.  What we should do is... try to find in in the array, if not, try to find it in an array of cut papers... if not, then special cut it...
			my @papers;

			if ( $Press->specification('Feed') eq 'Web' ) {
				foreach my $Paper ( @Papers ) {
					if ( $Paper->type() eq 'Roll' ) {

						if ( $Paper->width() > $Press->specification('Maximum Sheet Width') ) {
							next;
						} # end if
						my $P = $Paper->clone();
						my @imps = openprint::imposition::get_imposition( \%project, $do_work_turn, $do_perfecting, $$specs{'Versions'}, $P,
								( $$specs{'chkOverrideRunStyle'.$qty_index} eq 'Y' ? $$specs{'ddmRunStyle'.$qty_index} : undef ), 
								( $$specs{'chkOverrideGrainDirection'.$qty_index} eq 'Y' ? $$specs{'rdbGrainDirection'.$qty_index} : undef ), $Press,
								);
						if ( $P->start_width() ) {
							push @impositions, @imps;
						} else {
							foreach my $i ( @imps ) {
								my $i2 = $i;
								while ( $i2->columns() ) {
									push @impositions, $i2;
									$i2 = $i2->copy();
									$i2->columns( $i2->columns()-1 );
									$i2->paper()->width( $i2->used_width() );
									openprint::imposition::check_setup( $i2, \%project );
									$i2->columns(0) if $Press->specification('Minimum Sheet Width') and ($i2->paper()->width() < $Press->specification('Minimum Sheet Width'));
								} # end while
							} # end foreach
						} # end if

					} # end if
				} # end foreach
			} else { # Sheet Fed
				my %imps;
				foreach my $Paper ( @Papers ) {
					next if $Paper->type() eq 'Roll';
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
								$openprint::log->debug("Next paper because it's too small for the item" . $P->width() . 'x' . $P->height() . ' => ' . $$specs{'txtWidth'} . 'x' . $$specs{'txtHeight'} ) if $debug;
								last;
							} # end if

							my @imps = openprint::imposition::get_imposition( \%project, $do_work_turn, $do_perfecting, $$specs{'Versions'}, $P,
									( $$specs{'chkOverrideRunStyle'.$qty_index} eq 'Y' ? $$specs{'ddmRunStyle'.$qty_index} : undef ), 
									( $$specs{'chkOverrideGrainDirection'.$qty_index} eq 'Y' ? $$specs{'rdbGrainDirection'.$qty_index} : undef ),
									$Press );
							last if ! @imps;
						
#$openprint::log->debug("Sorting");	
							foreach my $imp ( @imps ) {
								my $add = 0;
#$imp->display();
								if ( $imps{$imp->imposition().$imp->runstyle()} ) {
#$openprint::log->debug("Exists " . @{$imps{$imp->imposition().$imp->runstyle()}} );
									for ( my $j = 0; $j < @{$imps{$imp->imposition().$imp->runstyle()}}; $j += 1 ) {

										my $I = $imps{$imp->imposition().$imp->runstyle()}[$j];
										my %BiggerPrice = $I->Paper()->get_price($qty/$I->imposition());
										my %SmallerPrice = $imp->Paper()->get_price($qty/$imp->imposition());
										if ( $I->Paper()->area() > $P->area() ) {
											if ( (1*$BiggerPrice{'100lb'}) == (1*$SmallerPrice{'100lb'}) ) {
												splice @{$imps{$imp->imposition().$imp->runstyle()}}, $j, 1;
											} # end if
											$add = 1;
										} else { # same or smaller area
											if ( $I->dutch_orientation() and ! $imp->dutch_orientation() ) {
												splice @{$imps{$imp->imposition().$imp->runstyle()}}, $j, 1;
												$add = 1;
											} elsif ( (1*$BiggerPrice{'100lb'}) < (1*$SmallerPrice{'100lb'}) ) {
												$add = 1;
											} # end if
										} # end if
									} # end for
								} else {
									$add = 1;
								} # end if
								push @{$imps{$imp->imposition().$imp->runstyle()}}, $imp if $add;
							} # end foreach

							last if ( ! $P->cuttable() );
							$P = $P->clone();
							$P->cut();
						} # end while cutting it
					} # end foreach $Paper
					#@impositions = values %imps;
					@impositions = map {@{$_}} values %imps;
				}# end if Web or Sheet

				if ( ! @impositions ) {
#$openprint::log->debug("No impositions for press " . $Press->strid()) if $debug;
					if ( $$specs{'chkOverridePress'.$qty_index} eq 'Y' ) {
						$$specs{'alert'} .= 'There were no possible impositions.  Your project may be too large for us.<br/>';
						return $$specs{'Status'} = 'uncalculated';
					} # end if
					next;
				} # end if

				$imposition_count += scalar @impositions;
				$impositions{$Press->id()} = \@impositions;
		} # end foreach Press
# FIXME
if ( 0 ) {
		if ( $$specs{'ddmPress'.$qty_index} and $$specs{'chkOverridePress'.$qty_index} ne 'Y' ) {
			my @Press = openprint::Equipment::find('strid'=>$$specs{'ddmPress'.$qty_index});
			if ( @Press and sets::isin( $Press[0]->id(), map { $_->id() } @possible_presses ) ) {
				my $old_impo = new openprint::Imposition();
$openprint::log->debug("Loaing old imp");
				$old_impo->load( $specs, $qty_index );
				$old_impo->Press( $Press[0] );
				$impositions{''} = [ $old_impo ];
				if ( $Press[0]->specification('Cut Off') and ! $old_impo->paper()->height() ) {
					$old_impo->paper()->height( $Press[0]->specification('Cut Off') );
					$old_impo->paper()->start_height( $Press[0]->specification('Cut Off') );
				} # end if
			} # end if
		} # end if
} # end if

		if ( ! $imposition_count ) {
			$$specs{'alert'} .= 'There were no possible impositions for your specifications.<br/>';
			return $$specs{'Status'} = 'uncalculated';
		} # end if

		# Only thread qtys 2 and 3
		if ( $threading and $qty_index > 1 ) {
			$threads{$qty_index} = threads->create( sub { 
				$openprint::log->debug( "Created thread:" . $qty_index );

				$openprint::dbh = sql::open_sql( $openprint::log, 
					'database'	=> $openprint::r->dir_config('db_name'),
					'driver'	=> $openprint::r->dir_config('db_driver'), 
					'host'		=> $openprint::r->dir_config('db_host'),
					'login'		=> $openprint::r->dir_config('db_user'),
					'password'	=> $openprint::r->dir_config('db_password'),
					);
				return get_project_price( $Project, $service_index, \@side_one_colours, \@side_two_colours, \@filtered_colours, \%special_colours, \%inkCoverage, \%mixed_colours, \%washed_colours, \%project, $specs, $qty, $qty_index, \@possible_presses, $printing_specs, \%impositions );
				} );
		} else {
			$prices{$qty_index} = get_project_price( $Project, $service_index, \@side_one_colours, \@side_two_colours, \@filtered_colours, \%special_colours, \%inkCoverage, \%mixed_colours, \%washed_colours, \%project, $specs, $qty, $qty_index, \@possible_presses, $printing_specs, \%impositions );
		} # end if

	} # end foreach quantity

	foreach my $qty_index ( reverse @blah ) {
		my $qty = $Project->quantity($qty_index);
		next if ! defined $qty;
		next if ! int $qty;

		$$specs{'hdnBreakdown'.$qty_index} = "QTY: $qty: ";
		$qty *= $$specs{'PageQuantity'} if $$specs{'PageQuantity'};
		$qty *= $$specs{'txtNameQuantity'} if $$specs{'txtNameQuantity'};
		if ( $threading and $qty_index > 1 ) {
			$prices{$qty_index} = $threads{$qty_index}->join();
		} # end if
		my $b_price = $prices{$qty_index};

		if ( ! $b_price ) {
			$$specs{'alert'} .= 'Unable to calculate a price';
			return $$specs{'Status'} = 'uncalculated';
		} # end if

		my %best_price = %{$b_price};

		my $Imposition = $$b_price{'Imposition'};
		my $Paper = $Imposition->paper();
		my $Press = $Imposition->Press();
		my $Aqueous = $$b_price{'Aqueous'};
		my $Varnish = $$b_price{'Varnish'};
		$$specs{'hdnBreakdown'.$qty_index} = breakdown( $b_price, $specs );
		$$specs{'txtStockGSM'} = $Imposition->Paper()->gsm();
		$$specs{'ddmBleedSize'.$qty_index} = $best_price{'ddmBleedSize'};
		$$specs{'ddmRunStyle'.$qty_index} = $Imposition->runstyle();
		$$specs{'ddmPress'.$qty_index} = $Press->strid();
		$$specs{'PrintingType'.$qty_index} = $Press->specification('Printing Type');
		$$specs{'txtImageWidth'.$qty_index} = $Imposition->image_width();
		$$specs{'txtImageHeight'.$qty_index} = $Imposition->image_height();
		$$specs{'txtLayoutWidth'.$qty_index} = $Imposition->layout_width();
		$$specs{'txtLayoutHeight'.$qty_index} = $Imposition->layout_height();
		if ( $Paper->width() and $Paper->height() ) {
			$$specs{'ddmStockSheetSize'.$qty_index} = $Paper->width() . 'x' . $Paper->height();
		} elsif ( $Paper->width() ) {
			$$specs{'ddmStockSheetSize'.$qty_index} = $Paper->width() . '" Roll';
		} # end if
		$$specs{'txtMWeight'.$qty_index} = $Paper->mweight() ? $Paper->mweight() : $Paper->wpsi() * $Paper->width() * $Paper->height() * 1000;
		$$specs{'rdbGrainDirection'.$qty_index} = $Imposition->grain_direction();
		if ( $Paper->type() eq 'Roll' ) {
			$$specs{'txtPressSheetQty'.$qty_index} = sprintf('%.0f lbs', $best_price{'Gross Sheet Count'} * $Paper->width() * $Paper->height() * $Paper->wpsi() );
		} elsif ( $Paper->type() eq 'Sheet' ) {
			$$specs{'txtPressSheetQty'.$qty_index} = $best_price{'Gross Sheet Count'} .'sheets';
			$$specs{'hdnNetSheetCount'.$qty_index} = $best_price{'Net Sheet Count'};
			$$specs{'SheetQuantity'.$qty_index} = $best_price{'Gross Sheet Quantity'};
		} else {
			$$specs{'txtPressSheetQty'.$qty_index} = 0;
			$$specs{'hdnNetSheetCount'.$qty_index} = 0;
			$$specs{'SheetQuantity'.$qty_index} = 0;
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

		$$specs{'StitchingImposition'.$qty_index} = $best_price{'StitchingImposition'};
		$$specs{'FoldingImposition'.$qty_index} = $best_price{'FoldingImposition'};
		$$specs{'txtImposition'.$qty_index} = $Imposition->imposition();
		$$specs{'hdnImpositionRows'.$qty_index} = $Imposition->rows();
		$$specs{'hdnImpositionColumns'.$qty_index} = $Imposition->columns();
		$$specs{'hdnImpositionDutchRows'.$qty_index} = $Imposition->dutch_rows();
		$$specs{'hdnImpositionDutchColumns'.$qty_index} = $Imposition->dutch_columns();
		$$specs{'hdnImageOrientation'.$qty_index} = $Imposition->image_orientation();
		$$specs{'SpreadRows'.$qty_index} = $Imposition->spread_rows();
		$$specs{'SpreadCols'.$qty_index} = $Imposition->spread_columns();

		$$specs{'hdnImpressionQuantity'.$qty_index} = $best_price{'Impressions'};
#$$specs{'RunTime'.$qty_index} = $best_price{'RunTime'};

		$$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{'ProjectMoneyFormat'}, $best_price{'Total Cost'} );
		$$specs{'txtUnitPrice'.$qty_index} = sprintf('%.2f', $best_price{'Total Cost'} / $qty );
		my $mprice = $best_price{'Impression Price'};
		$mprice += $$Varnish{'Run Total'} + $$Varnish{'Material Total'} if %$Varnish;
		$mprice += $$Aqueous{'Total'} if %$Aqueous;
		
		$$specs{'MPrice'.$qty_index} = sprintf('%.2f', ((($mprice + $best_price{'Ink Price'} )/ $qty)*1000 ) + $best_price{'Paper 1000 Price'} );

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
	my $Paper = $Imposition->paper();
	my $Press = $Imposition->Press();
	my $Aqueous = $$price{'Aqueous'};
	my $Varnish = $$price{'Varnish'};

	my $breakdown = '';
	$breakdown .= sprintf("Colour Bar \%s \%s<br/>", $Imposition->colour_bar_size(), $Imposition->colour_bar_orientation() );
	$breakdown .= sprintf('<b>Setups:</b><br/>Press Setup: $%.2f<br/>', $$price{'Press Setup'} );
$breakdown .= $$price{'Setup Breakdown'};
	$breakdown .= sprintf("\tImposition Charge:\t\$%1\$.2f + \$%2\$.2f*\%4\$d=\$%3\$.2f<br/>", @$price{'Imposition MakeReady','Imposition Price','Imposition Total'}, $Imposition->imposition() );
	$breakdown .= sprintf("\tRunstyle Charge:\t\$%.2f<br/>", $$price{'Runstyle Charge'} );
	$breakdown .= sprintf("\tWork & Turn Dry Cost:\t\$%.2f<br/>", @$price{'WorkTurn Dry Charge'} ) if $$price{'WorkTurn Dry Charge'};
	$breakdown .= sprintf("\tAqueous Setup:\t\$%.2f<br/>", $$Aqueous{'Setup'}) if $$Aqueous{'Setup'};
	$breakdown .= sprintf("\tPMS Ink Mix Charge:\t\$%.2f<br/>", $$price{'Ink Mix Charge'} ) if $$price{'Ink Mix Charge'};
	$breakdown .= sprintf("\tInline Varnish Setup Charge: \$%.2f<br/>", $$Varnish{'Setup'} ) if $$Varnish{'Setup'};
	$breakdown .= sprintf("\tPress Wash Charge:\t\$%.2f * \%d washes = \$%.2f<br/>", @$price{'Press Wash Price','Press Washes','Press Wash Total'});
	$breakdown .= sprintf("\tSetup Total:\t\t\$%.2f<br/><b>Run Charges:</b><br/>", $$price{'Setup Total'} );
	$breakdown .= sprintf('Impression Charge: %d Impressions/%d Per Hour * $%.2f%s = $%.2f<br/>', @$price{'Impressions','Run Speed','Impression Cost','Impression Units','Impression Price'} );
	$breakdown .= sprintf("\tInline Varnish Charge: \$%.4f\%s = %.2f<br/>", @$Varnish{'run_price','Run Units','Run Total'} ) if %$Varnish;;
# if $$Varnish{'run_price'};
	$breakdown .= sprintf("\tAqueous Run Charge: %.2f%s = \$%.2f<br/>", @$Aqueous{'Run Cost','Units','Total'} ) if %$Aqueous;;
	$breakdown .= sprintf("\tMinimum Run Charge: \$%.2f<br/>", $$price{'Minimum Run Charge'} );
	$breakdown .= sprintf("\tRun Charge Total:\t\$%.2f<br/>", $$price{'Run Total'} );
	$breakdown .= '<b>Material Charges:</b><br/>';
	my $plate_costs = $$price{'Plate Costs'};
	$breakdown .= sprintf( "\tPlates: \%d plates * \$%.2f per plate = \$%.2f<br/>", @$price{'txtPlateQuantity','Plate Cost','Plate Price'});
	$breakdown .= sprintf( 'Blank Plates: %d plates * $%.2f per plate = $%.2f<br/>', @$plate_costs{'Blank Plates','Blank Price'}, $$plate_costs{'Blank Price'} * $$plate_costs{'Blank Plates'}) if defined $$plate_costs{'Blank Plates'};
	my $stock_qty = $$price{'Stock Quantity'};
	$breakdown .= sprintf( 'Overs: Base:%s Run:%s FM:%s Additional Plate:%s Total:%s<br/>', @$stock_qty{'Setup Overs','Run Overs','FM Overs','Additional Plate Overs', 'Total Overs'} );
	if ( $Paper->type() ne 'Roll' ) {
		$breakdown .= sprintf( '%sx%s starting %sx%s<br/>', $Paper->width(), $Paper->height(), $Paper->start_width(), $Paper->start_height() );
		$breakdown .= "\tPaper: $$price{'Gross Sheet Count'} sheets @".$Paper->mweight() . 'M = ' . $$price{'Gross Sheet Count'} * $Paper->mweight()/1000 . 'lbs * ';
		$breakdown .= "(\$ $$Paper{'Per M'} Per M) " if $$Paper{'Per M'};
		$breakdown .= " (\$ $$price{'100lb'}/100lb) = \$ $$price{'Paper Price'}<br/>";
		$$price{'Paper 1000 Price'} = ($$price{'Sheet Price'}*1000/$Imposition->imposition());
	#} elsif ( $Paper->width() ) {
	} else {
		$breakdown .= sprintf("\tPaper: \%sx\%s * \%.6flbs/sq inch = \%.6f lbs per sheet (%d gsm)<br/>", $Paper->width(), $Paper->height(), $Paper->wpsi(), $Paper->width() * $Paper->height()* $Paper->wpsi(), $Paper->gsm() );
		$$price{'Paper 1000 Price'} = (($Paper->mweight()/$Imposition->imposition())/100)*$$price{'100lb'};

		$breakdown .= sprintf("\tPaper: %.0f lbs * \$%.2f/100lb = \$%.2f<br/>", @$price{'Stock Weight','100lb','Paper Price'});
	} # end if
	if ( $$specs{'rdbSuppliedStock'} eq 'Y' ) {
		$breakdown .= "\tPaper Price not included in total<br/>";
	} # end if
	$breakdown .= $$price{'Ink breakdown'};
	$breakdown .= sprintf("\tInk Total: \$%.2f<br/>", $$price{'Ink Price'} );
	$breakdown .= sprintf("\tVarnish: \$%.4f\%s = \$%.2f<br/>", @$Varnish{'Material Price','Material Units','Material Total'} ) if %$Varnish;
	$breakdown .= "Total: $$price{'Total Cost'}<br/>";
	$breakdown .= $$price{'Folding Breakdown'};
	$breakdown .= $$price{'Cutting Breakdown'};
	$breakdown .= $$price{'Scoring Breakdown'} if $$price{'Scoring Breakdown'};
	$breakdown .= $$price{'Perforating Breakdown'} if $$price{'Perforating Breakdown'};
	$breakdown .= $$price{'Stitching Breakdown'};
	$breakdown .= $$price{'AdditionalSignature Breakdown'};
	$breakdown .= sprintf("Comparison Cost: \%.2f<br/>", $$price{'Comparison Cost'});
	return $breakdown;
} # end sub breakdown

# impositions is a hash of imps for each press

sub get_project_price {
	my ( $Project, $service_index, $side_one_colours, $side_two_colours, $filtered_colours, $special_colours, $inkCoverage, $mixed_colours, $washed_colours, $project, $specs, $qty, $qty_index, $possible_presses, $printing_specs, $impositions ) = @_;

	my %prices;
	foreach my $Press ( $$specs{'chkOverridePress'.$qty_index} eq 'Y' ? openprint::Equipment::find('strid'=>$$specs{'ddmPress'.$qty_index} ) : ('', @$possible_presses) ) {

		if ( ! $Press ) {
			if ( $$impositions{''} and @{$$impositions{''}} ) {
				$Press = $$impositions{''}[0]->Press();
			} # end if
		} # end if
		next if ! $Press;
		$prices{$Press->id()} = get_price_for_press( $Project, $service_index, $side_one_colours, $side_two_colours, $filtered_colours, $special_colours, $inkCoverage, $mixed_colours, $washed_colours, $project, $specs, $qty, $qty_index, $possible_presses, $printing_specs, $impositions, $Press ); 

	} # end foreach Press
#$openprint::log->debug("Threading");

	my $best_price;
	foreach my $Press ( keys %prices ) {
		if ( (! $best_price ) or ( $prices{$Press}{complete} and ($$best_price{'Comparison Cost'} > $prices{$Press}{'Comparison Cost'} ) ) ) {
			$best_price = $prices{$Press};
		} # end if
	} # end foreach

	if ( ! $best_price ) {
		$$specs{'alert'} .= "Unable to calculate a price for printing for qty $qty_index.<br/>";
		$$specs{'Status'} = 'uncalculated';
		return;
	} # end if
	return $best_price;
} # end sub get_project_price

sub get_price_for_press {
	my ( $Project, $service_index, $side_one_colours, $side_two_colours, $filtered_colours, $special_colours, $inkCoverage, $mixed_colours, $washed_colours, $project, $specs, $qty, $qty_index, $possible_presses, $printing_specs, $impositions, $P ) = @_;

$openprint::log->debug("get_price_for_press: " . $P );
		my @impositions;
		my $Press;
		if ( ! $P ) {
			if ( $$impositions{''} and @{$$impositions{''}} ) {
				@impositions = @{$$impositions{''}};
				$Press = $impositions[0]->Press();
			} # end if
		} else {
#next;
			$Press = $P;
			@impositions = @{$$impositions{$Press->id()}} if $$impositions{$Press->id()};
		} # end if
		if ( ! $Press ) {
			#$openprint::log->debug("No Press");
			return;
		} # end if
$openprint::log->debug("get_price_for_press: " . $P->name() );


	my $best_price;
	# indexed by # of spreads
	my %additional_signature_cache;

	my $SpreadLayout;
	if ( $$specs{'txtSignatureType'} ) {
		if ( $$specs{'chkOverridePageQuantity'.$qty_index} eq 'Y' ) {
			$SpreadLayout = $$specs{'PageQuantity'.$qty_index} / $$specs{'txtSpreadSize'};
		} else {
			$SpreadLayout = $$specs{'txtUnspecifiedPageQuantity'.$qty_index} / $$specs{'txtSpreadSize'};
		} # end if
	} # end if
	if ( $SpreadLayout > 0 ) {
		$openprint::log->debug("Converting Impositions spread Layout: $SpreadLayout : imps:" . @impositions) if $debug;
		@impositions = openprint::imposition::convert_impositions( $SpreadLayout, $$specs{'txtSpreadSize'}, \@impositions );
$openprint::log->debug("Impositions for Press: " . $Press->strid() . ' after convert:' . @impositions) if $debug;
	} # end if
# Gives us both inline and offline folding options
	if ( $$project{'HasFolding'} ) {
		@impositions = map { openprint::Estimating::Folding::impositions( $Project, $_, $$project{'FoldingSpecs'}, $specs, $qty_index ) } @impositions;
$openprint::log->debug("Impositions for Press: " . $Press->strid() . ' after folding:' . @impositions) if $debug;
	} # end if Folding

	my $pms_prices = get_special_colours_price( $Press, $filtered_colours, $mixed_colours, $washed_colours, $special_colours, $qty_index );

		if ( 0 ) {
		foreach my $imp ( @impositions ) {
$imp->display();
	} # end foreach
	} # end if
	$openprint::log->debug("Number of impositions to consider for " . $Press->strid() . ': ' . scalar @impositions);
	foreach my $imp ( @impositions ) {
		next if ( ( $$specs{'chkOverrideImposition'.$qty_index} eq 'Y' ) and ( $imp->imposition() != $$specs{'txtImposition'.$qty_index} ) );
		if ( ( $$specs{'chkOverridePageQuantity'.$qty_index} eq 'Y' ) and ( $imp->pages() != $$specs{'PageQuantity'.$qty_index} ) ) {
			#$openprint::log->debug("Doesn't match page quantity override " . $imp->pages() . ' != ' . $$specs{'PageQuantity'.$qty_index});
		}
		if ( $$specs{'chkOverrideSheetSize'.$qty_index} ) {
			if ( $$specs{'OverrideStockHeight'.$qty_index} ) {
				if ( $imp->paper()->width() != $$specs{'OverrideStockWidth'.$qty_index} or $imp->paper()->height() != $$specs{'OverrideStockHeight'.$qty_index} ) {
					$openprint::log->debug("Wrong stock want : ".$$specs{'OverrideStockWidth'.$qty_index}.'x'.$$specs{'OverrideStockHeight'.$qty_index}." but have " . $imp->paper()->width() . 'x'.$imp->paper()->height() );
					next;
				} # end if
			} else {
				if ( $imp->paper()->width() != $$specs{'OverrideStockWidth'.$qty_index} ) {
					$openprint::log->debug("Wrong stock want : ".$$specs{'OverrideStockWidth'.$qty_index}." but have " . $imp->paper()->width());
					next;
				} # end if
			} # end if
		} # end if
#my $starttime = gettimeofday();
$imp->display();

#my $time = gettimeofday();
		my $price = calc_price( $Project, $service_index, $imp, $project, $Project->services(), $specs, $qty, $qty_index, $side_one_colours, $side_two_colours, $filtered_colours, $washed_colours, $mixed_colours, ($best_price ? $$best_price{'Comparison Cost'} : 0), $pms_prices, $inkCoverage, $special_colours );
#$openprint::log->debug("Main Calc Price time: " . ( sprintf('%.4f', tv_interval( [$time])*1000) ) .' usecs' );

		if ( $$specs{'txtUnspecifiedPageQuantity'.$qty_index} and $imp->pages() ) {
			my $upq = $$specs{'txtUnspecifiedPageQuantity'.$qty_index};
			my $pp = $$specs{'PreviousPlates'.$qty_index};
			my $pbp = $$specs{'PreviousBlankPlates'.$qty_index};

			$$specs{'txtUnspecifiedPageQuantity'.$qty_index} -= $imp->pages();

			my $s_id = 0;
			my %new_specs = %$specs;

			while ( $$specs{'txtUnspecifiedPageQuantity'.$qty_index} > 0 ) {
				foreach ( $Project->signatures($$specs{'txtSignatureType'}) ) {
					if ( $s_id and ($_ > $s_id) ) {
						$s_id = $_;
						%new_specs = %{openprint::service::get_specs_ref( $Project, $s_id )};
						last;
					} # end if
				} # end foreach

# Need to update these too. 
				$new_specs{'PreviousPlates'.$qty_index} += $$price{'txtPlateQuantity'};
				$new_specs{'PreviousBlankPlates'.$qty_index} += $$price{'txtBlankPlateQuantity'};

				my $last_sig_price = $$price{'Comparison Cost'};

				my $additional_price;
				my $sig_price;
				if ( $$specs{'txtUnspecifiedPageQuantity'.$qty_index} >= $imp->pages() ) {
# Going to just re-use the same impo
#$openprint::log->warn("Doing half calc qtyi: $qty_index unspec: $$specs{'txtUnspecifiedPageQuantity'.$qty_index} > " . $imp->spreads() . ' imp spreads');
##$Imposition->display();

#my $time = gettimeofday();
#n$new_specs{'no_stitching'} = 1; # unneccessary calculation
					$sig_price = calc_price( $Project, $s_id, $imp, $project, $Project->services(), \%new_specs, $qty, $qty_index, $side_one_colours, $side_two_colours, $filtered_colours, $washed_colours, $mixed_colours, ( $best_price ? $$best_price{'Comparison Cost'}-$$sig_price{'Comparison Cost'} : 0 ), $pms_prices, $inkCoverage, $special_colours );
#$openprint::log->debug("2 Calc Price time: " . ( sprintf('%.4f', tv_interval( [$time])*1000) ) .' usecs' );
#$new_specs{'no_stitching'} = 0; # unneccessary calculation
					$additional_price = $$sig_price{'Comparison Cost'};

					if ( $$sig_price{'Comparison Cost'} == $last_sig_price ) {
						$additional_price -= $$sig_price{'Stitching Cost'};
						$additional_price *= int($$specs{'txtUnspecifiedPageQuantity'.$qty_index}/$imp->pages());
						$additional_price += $$sig_price{'Stitching Cost'};
						#last if $$specs{'txtUnspecifiedPageQuantity'.$qty_index} % $imp->pages() >= $$specs{'txtUnspecifiedPageQuantity'.$qty_index};
						$$specs{'txtUnspecifiedPageQuantity'.$qty_index} = $$specs{'txtUnspecifiedPageQuantity'.$qty_index} % $imp->pages();
					} else {
						$$specs{'txtUnspecifiedPageQuantity'.$qty_index} -= $imp->pages();
					} # end if
					# This is crucial because we might fall through to the next case on the next iteration, and New_specs needs to be uptodate
					$new_specs{'txtUnspecifiedPageQuantity'.$qty_index} = $$specs{'txtUnspecifiedPageQuantity'.$qty_index};

#$openprint::log->debug("Additional sig cost of " . $imp->spreads() . "spreads is : $additional_price. Leaving " . $$specs{'txtUnspecifiedSpreadQuantity'.$qty_index});
#$openprint::log->warn("Done half calc: price: $sig_price{'Comparison Cost'}");
				} else {
					if ( $additional_signature_cache{$new_specs{'txtUnspecifiedPageQuantity'.$qty_index}} ) {
#$openprint::log->debug("Using cache: " . $additional_signature_cache{$new_specs{'txtSignatureSpreadQuantity'.$qty_index}}{complete} . ': ' . $additional_signature_cache{$new_specs{'txtSignatureSpreadQuantity'.$qty_index}}{'Comparison Cost'} );
						#$sig_price = $additional_signature_cache{$new_specs{'txtSignatureSpreadQuantity'.$qty_index}};
$sig_price = calc_price( $Project, $s_id, $additional_signature_cache{$new_specs{'txtUnspecifiedPageQuantity'.$qty_index}}, $project, $Project->services(), \%new_specs, $qty, $qty_index, $side_one_colours, $side_two_colours, $filtered_colours, $washed_colours, $mixed_colours, ( $best_price ? $$best_price{'Comparison Cost'}-$$sig_price{'Comparison Cost'} : 0 ), $pms_prices, $inkCoverage, $special_colours );
					} else {
#$openprint::log->warn("Doing full calc $$specs{'txtUnspecifiedPageQuantity'.$qty_index} <= " . $imp->spreads() );
						my $services = $Project->services();
						my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
						$new_specs{'chkOverridePageQuantity'.$qty_index} = 'Y';
						$new_specs{'PageQuantity'.$qty_index} = $$specs{'txtUnspecifiedPageQuantity'.$qty_index};
#$openprint::log->debug("Additional pages:" .  $new_specs{'PageQuantity'.$qty_index} );
						$new_specs{'chkOverridePress'.$qty_index} = 'Y';
						$new_specs{'chkOverrideSheetSize'.$qty_index} = '';
						$new_specs{'chkOverrideRunStyle'.$qty_index} = '';
						$new_specs{'chkOverrideImposition'.$qty_index} = '';
#$openprint::log->warn("Doing full calc $$specs{'txtUnspecifiedSpreadQuantity'.$qty_index} <= " . $imp->spreads() );
						$sig_price = get_project_price( $Project, $s_id, $side_one_colours, $side_two_colours, $filtered_colours, $special_colours, $inkCoverage, $mixed_colours, $washed_colours, $project, \%new_specs, $qty, $qty_index, $possible_presses, $printing_specs, $impositions );
#$openprint::log->debug("got price: " . $additional_signature_cache{$new_specs{'PageQuantity'.$qty_index}}{complete} . ': ' . $additional_signature_cache{$new_specs{'PageQuantity'.$qty_index}}{'Comparison Cost'} );
						if ( ! $$sig_price{'complete'} ) {
							$new_specs{'chkOverridePageQuantity'.$qty_index} = '';
#$openprint::log->warn("Doing full calc without Page Override" );
							$sig_price = get_project_price( $Project, $s_id, $side_one_colours, $side_two_colours, $filtered_colours, $special_colours, $inkCoverage, $mixed_colours, $washed_colours, $project, \%new_specs, $qty, $qty_index, $possible_presses, $printing_specs, $impositions );
						} # end if
						if ( ! $$sig_price{'complete'} ) {
#$openprint::log->warn("Doing full calc without Press Override" );
							$new_specs{'chkOverridePress'.$qty_index} = '';
							$sig_price = get_project_price( $Project, $s_id, $side_one_colours, $side_two_colours, $filtered_colours, $special_colours, $inkCoverage, $mixed_colours, $washed_colours, $project, \%new_specs, $qty, $qty_index, $possible_presses, $printing_specs, $impositions );
						} # end if
#$openprint::log->debug("Caching: " . $new_specs{'PageQuantity'.$qty_index} . ' : ' . $$sig_price{'Imposition'} );
						#$additional_signature_cache{$new_specs{'txtSignatureSpreadQuantity'.$qty_index}} = $sig_price;
						$additional_signature_cache{$new_specs{'PageQuantity'.$qty_index}} = $$sig_price{'Imposition'};

						# get_project_price is recursive so we are done
						$$specs{'txtUnspecifiedPageQuantity'.$qty_index} = 0;
						$new_specs{'txtUnspecifiedPageQuantity'.$qty_index} = $$specs{'txtUnspecifiedPageQuantity'.$qty_index};
						
#$openprint::log->debug("got price: " . $additional_signature_cache{$new_specs{'txtSignatureSpreadQuantity'.$qty_index}}{complete} . ': ' . $additional_signature_cache{$new_specs{'txtSignatureSpreadQuantity'.$qty_index}}{'Comparison Cost'} . ' ' . $$sig_price{'Comparison Cost'} - $$sig_price{'Stitching Cost'} );
					} # end if
					$additional_price = $$sig_price{'Comparison Cost'};

					if ( ! $$sig_price{'Imposition'} ) {
#$openprint::log->debug("No Imposition found.");
						$$sig_price{'complete'} = 1;
						$additional_price = 1000000;
						$$specs{'txtUnspecifiedPageQuantity'.$qty_index} = 0;
					} else {
#$openprint::log->debug("Additional sig cost: $additional_price.");
						$$specs{'txtUnspecifiedPageQuantity'.$qty_index} -= $$sig_price{'Imposition'}->pages();
					} # end if
#$openprint::log->warn("Done full calc $sig_price{'Comparison Cost'} :". $$specs{'PageQuantity'.$qty_index});
				} # end if

				$additional_price -= $$sig_price{'Stitching Cost'};
				$$price{'Comparison Cost'} -= $$price{'Stitching Cost'};
				$$price{'Stitching Cost'} = $$sig_price{'Stitching Cost'};
				$$price{'Comparison Cost'} += $$price{'Stitching Cost'};

				$$price{'StitchingImposition'} = $$sig_price{'StitchingImposition'};
				$$price{'Stitching Breakdown'} = $$sig_price{'Stitching Breakdown'};

				if ( ! $$sig_price{complete} ) {
$openprint::log->debug("Unable to calculated");
					$$price{'complete'} = 0;
					$$price{'AdditionalSignature Breakdown'} .= 'Unable to calculate additional signatures.<br/>';
					last;
				} # end if

				if ( $additional_price < 0 ) {
					$$price{'complete'} = 0;
					$$price{'AdditionalSignature Breakdown'} .= 'Unable to calculate additional signatures.<br/>';
					last;
				} # end if	
				$last_sig_price = $$sig_price{'Comparison Cost'};

				$$price{'Comparison Cost'} += $additional_price;
				if ( $$sig_price{'Imposition'} ) {
					$$price{'AdditionalSignature Breakdown'} .= sprintf('Additional Sig %dpages %dout %s %.2f', $$sig_price{'Imposition'}->pages(), $$sig_price{'Imposition'}->imposition(), $$sig_price{'Imposition'}->runstyle(), $additional_price ) . '<br/>';
					#`:w
					$$price{'AdditionalSignature Breakdown'} .= breakdown( $sig_price, $specs );
				} else {
					$$price{'AdditionalSignature Breakdown'} .= 'Unable to calculate additional signatures.<br/>';
				} # end if
				#$$price{'AdditionalSignature Breakdown'} .= $$sig_price{'Cutting Breakdown'};
				#$$price{'AdditionalSignature Breakdown'} .= $$sig_price{'Stitching Breakdown'};
				last if $best_price and check_price( $$best_price{'Comparison Cost'}, $price, $specs, $qty_index, $imp, 'Sig' );
			} # end while
			$$specs{'txtUnspecifiedPageQuantity'.$qty_index} = $upq;
			$$specs{'PreviousPlates'.$qty_index} = $pp;
			$$specs{'PreviousBlankPlates'.$qty_index} = $pbp;
		} # end if UnspecifiedPageQuanitty
#$openprint::log->debug( 'calc_price: ' . sprintf('%.4f', tv_interval( [$starttime])*1000) . ' Complete: ' . $price{complete} );

		if ( ! $$price{complete} ) {
#$openprint::log->debug("No price complete ");
#$imp->display();
			next;
		} # end if

		if ( $$price{'Comparison Cost'} < 0 ) {

			$openprint::log->debug("Negative price! $$best_price{'Comparison Cost'} <= $$price{'Comparison Cost'}") if 1 or $debug;
			#$imp->display();
		} elsif ( $best_price and $$best_price{'Comparison Cost'} <= $$price{'Comparison Cost'} ) {
			#$openprint::log->debug("No good, more expensive $best_price{'Comparison Cost'} <= $$price{'Comparison Cost'}") if 1 or $debug;
			#$imp->display();
		} else {
$openprint::log->debug("Got better: $$best_price{'Comparison Cost'} > $$price{'Comparison Cost'}" );
			#$imp->display();
			$best_price = $price;
#$imp->display();
#keep track of the best price we have found so far.
# now that we have the pricing info arrange it in a hash and store it for later.
			#$best_price{'Imposition'} = $imp;
			$$best_price{'Press'} = $Press;
		} # end if 
		#$$imp{'PriceHash'} = $price;
		#$$imp{'Total'} = $$price{'Total Cost'};
		#$$imp{'Comparison'} = $$price{'Comparison Cost'};
	} # end foreach imposition

	return $best_price;

} # end sub get_project_price

sub check_price {
	my ( $price_to_beat, $price, $specs, $qty_index, $Imposition, $text ) = @_;

	return 0 if ! $price_to_beat;
	my $p = $$price{'Comparison Cost'};
	#if ( $$specs{'txtUnspecifiedPageQuantity'.$qty_index} ) {
		#$p *= ( 1 + ($$specs{'totalSpreads'}-$Imposition->spreads())/$Imposition->spreads() );
		#$p *= ( 1 + $$specs{'txtUnspecifiedPageQuantity'.$qty_index}/$Imposition->spreads() );
	#} # end if

#$openprint::log->debug("Check Price: $$price{'Comparison Cost'} $p > $price_to_beat: " . $Imposition->imposition().'out ' . $Imposition->spreads() .'spreads on ' . $Imposition->paper()->width().'x'.$Imposition->paper()->height(). " : $text") if $debug;
	#if ( $price_to_beat > $p ) {
	if ( $price_to_beat > $$price{'Comparison Cost'} ) {
		return 0;
	} # end if
	return 1;
} # end sub

# Takes and Imposition object, and calculates a Price Object.
# Does not need to take folding or Cutting into account, as those were chosen separately
sub calc_price {
	my ( $Project, $service_index, $Imposition, $project, $services, $specs, $qty, $qty_index, $side_one_colours, $side_two_colours, $filtered_colours, $washed_colours, $mixed_colours, $price_to_beat, $pms_prices, $inkCoverage, $special_colours ) = @_;

	my $Paper = $Imposition->Paper();
	my $Press = $Imposition->Press();

	# It's ok to do this, because $$specs is either a copy, or will be reset before being returned
	$$specs{"hdnImpositionRows$qty_index"} = $$Imposition{rows};
	$$specs{"hdnImpositionColumns$qty_index"} = $$Imposition{columns};
	$$specs{"hdnImpositionDutchRows$qty_index"} = $$Imposition{dutch_rows};
	$$specs{"hdnImpositionDutchColumns$qty_index"} = $$Imposition{dutch_columns};
	$$specs{"txtImposition$qty_index"} = $$Imposition{imposition};
	$$specs{'SpreadRows'.$qty_index} = $$Imposition{spread_rows};
	$$specs{'SpreadCols'.$qty_index} = $$Imposition{spread_columns};
	$$specs{'hdnImageOrientation'.$qty_index} = $$Imposition{image_orientation};
	$$specs{"txtSignaturePageQuantity$qty_index"} = $Imposition->pages();
	$$specs{'ddmPress'.$qty_index} = $Press->strid();
	$$specs{'txtStockGSM'} = $Paper->gsm();
	$$specs{'ddmRunStyle'.$qty_index} = $$Imposition{runstyle};

	my %price;
	$price{'Imposition'} = $Imposition;
	$price{'ddmBleedSize'} = $$project{'BleedSize'};

	my @colours = ();
	$price{'WorkTurn Dry Charge'} = 0;

#$log->debug("\n\n************ START OF CALC PRINT PRICE QTY: $qty 1: @$side_one_colours, @$side_two_colours CAL: $paper_calliper DT: $dry_trap  STYLE: $run_style ********* \n\n\n");
	my ( $is_sheetwork, $is_perfecting );
	if ( sets::isin( $$Imposition{runstyle},['Sheet Work','Web'] ) ) {
		$is_sheetwork = 1;
		$is_perfecting = 0;
		@colours = ( @$side_one_colours, @$side_two_colours );
	} elsif ( sets::isin( $$Imposition{runstyle}, ['Work & Turn','Work & Tumble'] ) ) {
		$is_sheetwork = 0;
		$is_perfecting = 0;
		$price{'WorkTurn Dry Charge'} = openprint::service::get_price( 'WTDrying', $Paper->grade(), $Press );
		@colours = @$filtered_colours;
	} elsif ( $$Imposition{runstyle} eq 'Perfecting' ) {
#$log->debug("************ WE HAVE PERFECTING ****************");
		$is_sheetwork = 1;
		$is_perfecting = 1;
		@colours = ( @$side_one_colours, @$side_two_colours );
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

	my $base_impressions = ceil($qty / $imposition);
	$base_impressions *= $$specs{'Versions'} if $$specs{'Versions'};

	#Initially we calculate based on colours, but really we need to calculate based on plates, which we will do once we figure out how many plates we need.
	my $min_overs = $Press->specification( 'Press Run Overs Minimum', scalar @colours );
	my $setup_rate = $Press->specification( 'Press Run Overs Rate', scalar @colours );
	my $setup_overs = $setup_rate * scalar @colours;
	my $fm_overs = $Press->specification( 'FM Screening Additional Overs', undef ) if $$specs{'ScreenType'} eq 'FM';
	$setup_overs += $fm_overs;
	$setup_overs = $min_overs if $setup_overs < $min_overs;

	my $over_rate = $Press->specification( 'Press Run Overs', $base_impressions );
	if ( $Press->specification( 'Double Overs For Covers' ) eq 'Yes' ) {
		$over_rate *= 2;
	} # end if
	my $run_overs = $base_impressions * $over_rate;
	my $impressions = sprintf( '%.0f', $base_impressions + ( $setup_overs > $run_overs ? $setup_overs : $run_overs ) );

	if ( $$specs{'txtPlateChangeQuantity'.$qty_index} ) {
		my $additional_overs = ( $$specs{'txtPlateChangeQuantity'.$qty_index} * $Press->specification('Additional Plate Overs') );
		my $minimum = $Press->specification('Additional Plate Overs Minimum');
		$additional_overs = $minimum if $minimum > $additional_overs;
		$impressions += $additional_overs;
	} # end if

	$impressions *= $$project{print_sides} if (sets::isin($$Imposition{runstyle},['Sheet Work','Work & Turn','Work & Tumble'] ));
	my $max_impression_quantity = $Press->specification('Maximum Impression Quantity', $$Paper{calliper} );
	if ( $max_impression_quantity and ($max_impression_quantity < $impressions ) ) {
		$openprint::log->debug("Next cuz of maximum impression quantity $max_impression_quantity : $impressions" ) if $debug;
		return \%price;
	} # end if
	my $min_impression_quantity = $Press->specification('Minimum Impression Quantity', $$Paper{calliper} );
	if ( $min_impression_quantity and ( $min_impression_quantity > $impressions ) ) {
		$openprint::log->debug("Next cuz of minimum impression quantity $min_impression_quantity: $impressions" ) if $debug;
		return \%price;
	} # end if
# Impressions are basically runs through the press
# Now that impressiosn is set, we can round up the Sheet Count to take into account the number of sheets in a package

	# Whya re we doing this here?
	#$$specs{'ddmRunStyle'.$qty_index} = $Imposition->runstyle();

	my %plate_setup = plate_setup_cost( $Imposition, $Press, $$Paper{width} * $$Paper{height}, $impressions, \@colours, $specs, $qty_index );
	# THis is here more to take care of multi-version documents as opposed to business cards
	#if ( ( $$specs{'Versions'} > 1 ) and sets::isin( $Imposition->runstyle(), ['Work & Turn','Work & Tumble' ] ) ) {
		#$plate_setup{'Plate Count'} *= ( $imposition / $$specs{'Versions'} );
	#} # end if

	my $press_setup = 0;
	if ( $$Imposition{runstyle} eq 'Sheet Work' ) {
		$_ = press_setup_cost( $openprint::log, $openprint::dbh, $openprint::variable, $Press, $$specs{'txtPlateChangeQuantity'.$qty_index}, $plate_setup{'Plate Runs'}, $side_one_colours, $$Paper{calliper}, $specs, $qty_index, $Project, $service_index, $Imposition );
		$press_setup += $_->{'Total'};
		$price{'Setup Breakdown'} .= sprintf('%d units * $%.2f%s = $%.2f<br/>', @$_{'Unit Count','Price','units','Total'} );
		$_ = press_setup_cost( $openprint::log, $openprint::dbh, $openprint::variable, $Press, $$specs{'txtPlateChangeQuantity'.$qty_index}, $plate_setup{'Plate Runs'}, $side_two_colours, $$Paper{calliper}, $specs, $qty_index, $Project, $service_index, $Imposition );
		$press_setup += $_->{'Total'};
		$price{'Setup Breakdown'} .= sprintf('%d units * $%.2f%s = $%.2f<br/>', @$_{'Unit Count','Price','units','Total'} );
	} elsif ( sets::isin( $$Imposition{runstyle}, ['Web','Perfecting'] ) ) {
		$_ = press_setup_cost( $openprint::log, $openprint::dbh, $openprint::variable, $Press, $$specs{'txtPlateChangeQuantity'.$qty_index}, $plate_setup{'Plate Runs'}, \@colours, $$Paper{calliper}, $specs, $qty_index, $Project, $service_index, $Imposition );
		$press_setup += $_->{'Total'};
		$price{'Setup Breakdown'} .= sprintf('%d units * $%.2f%s = $%.2f<br/>', @$_{'Unit Count','Price','units','Total'} );
	} else  {
		$_ = press_setup_cost( $openprint::log, $openprint::dbh, $openprint::variable, $Press, $$specs{'txtPlateChangeQuantity'.$qty_index}, $plate_setup{'Plate Runs'}, \@colours, $$Paper{calliper}, $specs, $qty_index, $Project, $service_index, $Imposition );
		$press_setup += $_->{'Total'};
		$price{'Setup Breakdown'} .= sprintf('%d units * $%.2f%s = $%.2f<br/>', @$_{'Unit Count','Price','units','Total'} );
	} # end if
	$price{'Plate Costs'} = \%plate_setup;
	$price{'Comparison Cost'} = $press_setup + ($plate_setup{'Plate Price'} * $plate_setup{'Plate Count'}) + ( $plate_setup{'Blank Price'} * $plate_setup{'Blank Plates'});

	#return if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Setup' );

	$price{'rdbPlates'} = $plate_setup{'Plate Type'};

	#Initially we calculate based on colours, but really we need to calculate based on plates, which we will do once we figure out how many plates we need.
	$min_overs = $Press->specification( 'Press Run Overs Minimum', $plate_setup{'Plate Count'} );
	$setup_rate = $Press->specification( 'Press Run Overs Rate', $plate_setup{'Plate Count'} );
	$setup_overs = $setup_rate * ( $plate_setup{'Plate Count'} );
	$setup_overs += $fm_overs;
	$setup_overs = $min_overs if $setup_overs < $min_overs;

	$run_overs = $base_impressions * $over_rate;
	#my $gross_qty = $impressions;
	my $gross_qty = sprintf( '%.0f', $base_impressions + ( $setup_overs > $run_overs ? $setup_overs : $run_overs ) );
	my $additional_overs=0;
	if ( $$specs{'txtPlateChangeQuantity'.$qty_index} ) {
		$additional_overs = ( $$specs{'txtPlateChangeQuantity'.$qty_index} * $Press->specification('Additional Plate Overs') );
		my $minimum = $Press->specification('Additional Plate Overs Minimum');
		$additional_overs = $minimum if $minimum > $additional_overs;
		$gross_qty += $additional_overs;
	} # end if
	$impressions = $gross_qty;
	my $weight = $gross_qty * $$Paper{width} * $$Paper{height} * $Paper->wpsi();
$openprint::log->debug("Weight: $weight");
	my $sheets_per_package = $Paper->sheets_per_package();
	if ( $sheets_per_package and $Paper->full_packages() ) {
		if ( $Paper->type() eq 'Sheet' ) {
			$gross_qty = $sheets_per_package * ceil( $gross_qty / $sheets_per_package );
		} elsif ( $Paper->type() eq 'Roll' ) {
			$weight = $sheets_per_package * ceil( $weight/$sheets_per_package);
			$gross_qty = $weight/($$Paper{width} * $$Paper{height} * $Paper->wpsi());
		} else {
			$openprint::log->error('Unknown paper type.');
		} # end if
	} # end if
	if ( $Paper->minimum_order() and ($Paper->minimum_order() > $weight) ) {
		$openprint::log->debug('Minimum Order Requirement not met');
		return \%price;
	} # end if
	
	my %sheet_qty = (
			'Impressions'				=> $impressions, 
			'Gross Sheet Count'			=> $gross_qty, 
			'Net Sheet Count'			=> $base_impressions,
			'Setup Overs'				=> $setup_rate * $plate_setup{'Plate Count'},
			'Run Overs'					=> $run_overs,
			'Additional Plate Overs'	=> $additional_overs,
			'Total Overs'				=> $impressions,
			'Weight'					=> $weight,
			'FM Overs'					=> $$specs{'ScreenType'} eq 'FM' ? 1*$fm_overs : 0,
			);
	$price{'Stock Quantity'} = \%sheet_qty;

	$price{'Gross Sheet Count'} = $sheet_qty{'Gross Sheet Count'};
	$price{'Net Sheet Count'} = $sheet_qty{'Net Sheet Count'};
	$price{'Film Cost'} =  $plate_setup{'Film Cost'};
	$price{'Plate Cost'} =  $plate_setup{'Plate Price'};
	$price{'txtPlateQuantity'} = $plate_setup{'Plate Count'};
	$price{'txtBlankPlateQuantity'} = $plate_setup{'Blank Plates'};
	$price{'Plate Price'} = $plate_setup{'Plate Price'} * $plate_setup{'Plate Count'};

	$price{'Stock Weight'} = $sheet_qty{'Weight'};
	my %paper_price = openprint::Estimating::Paper::sheet_calc( $openprint::log, $openprint::dbh, $openprint::variable, $Paper, $$Paper{type} eq 'Roll' ? $sheet_qty{'Weight'} : $sheet_qty{'Gross Sheet Count'} );
	@price{'Paper Cost', 'Paper Price', 'Sheet Cost', 'Sheet Price', '100lb'} = @paper_price{'Paper Cost', 'Paper Price', 'Sheet Cost', 'Sheet Price','100lb'};

	$price{'Comparison Cost'} += $price{'Paper Price'};
	return \%price if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Paper' );

	my $sheets = $impressions;
	$$specs{"txtPressSheetQty$qty_index"} = $sheets;
	$impressions *= $$project{print_sides} if (sets::isin($$Imposition{runstyle},['Sheet Work','Work & Turn','Work & Tumble'] ));

	my $run_speed = $Press->specification('Press Standard Run Speed', $Paper->gsm() );
	my %folding_results;

	# Has to be NEED because they always leave folding out, and it chooses dumb impositions
	if ( $$project{'NeedFolding'} ) {
#my $time = gettimeofday();
		%folding_results = openprint::Estimating::Folding::signature_calc( $Project, $service_index, $specs, $$project{'FoldingSpecs'}, $qty_index, $Paper, $Imposition );
#$openprint::log->debug("Folding Calculation time: " . ( sprintf('%.4f', tv_interval( [$time])*1000) ) .' usecs' );
		if ( $$project{'FoldingSpecs'}{'Status'} eq 'uncalculated' ) {
# do not want an invalid fold style to win out unless there are no other valid signatures.
			$price{'Comparison Cost'} += 1000000; 
			$openprint::log->debug("Unable to fold") if $debug;

		} # end if
		$price{'FoldingImposition'} = $folding_results{'Imposition'};
#$openprint::log->debug("FOlding IMPOSITION $folding_results{'Imposition'}");

		if ( $folding_results{'Equipment'} and ($folding_results{'Equipment'}->id() eq $Press->id() ) ) {
			my $fold_type = sprintf('%dx%d-%dPage-%sSignatureFoldRunSpeed', $$Imposition{spread_columns}, $$Imposition{spread_rows}, $Imposition->pages(), $$Imposition{image_orientation});

			if ( ! ( $run_speed = $Press->specification($fold_type, $Paper->gsm() ) ) ) {
#$openprint::log->debug("No specific fold run speed");
				if ( ! ( $run_speed = $Press->specification($Imposition->pages().'PageSignatureFoldRunSpeed', $Paper->gsm() ) ) ) {
#$openprint::log->debug("Not Using base fold run speed");
					$run_speed = $Press->specification('Press Standard Run Speed', $Paper->gsm() );
				} # end if
			} # end if
		} # end if

		if ( ! $run_speed ) {
			$openprint::log->warn("Got no runspeed.");
			return \%price;
		} # end if

		if ( $folding_results{'Equipment'} ) {
			$price{'Folding Breakdown'} .= sprintf('Folding (%d out) Price: $%.2f on %s', @folding_results{'Imposition','Price'}, $folding_results{'Equipment'}->name() ) .'<br/>' if $folding_results{'Equipment'};
		} else {
			$price{'Folding Breakdown'} .= sprintf('Unable to fold<br/>');
		} # end if
		$price{'Comparison Cost'} += $folding_results{'Price'};
		return \%price if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Folding' );
	} # end if
	$price{'Run Speed'} = $run_speed;
	my %run_price;
	my %aqueous = get_aqueous_price( $openprint::log, $openprint::dbh, $openprint::variable, $impressions, $Press, $is_sheetwork, $qty_index, $Project, $service_index, $specs ); 
	my %varnish_price;
	if ( sets::isin( $$Imposition{runstyle}, ['Work & Turn','Work & Tumble'] ) ) {
		%run_price = get_run_price( $impressions, scalar(@colours), 0, $Imposition, $Press, $run_speed ); 
		%varnish_price = get_varnish_run_price( $openprint::log, $openprint::dbh, $openprint::variable, $Press, $$project{print_sides}, $impressions, $specs, \@colours, undef, $qty_index, $Imposition, $Project, $service_index, $inkCoverage );
	} else {
		%run_price = get_run_price( $impressions, scalar @$side_one_colours, scalar @$side_two_colours, $Imposition, $Press, $run_speed ); 
		%varnish_price = get_varnish_run_price( $openprint::log, $openprint::dbh, $openprint::variable, $Press, $$project{print_sides}, $impressions, $specs, $side_one_colours, $side_two_colours, $qty_index, $Imposition, $Project, $service_index, $inkCoverage);
	} # end if

	$price{'Press Washes'} += $$pms_prices{'Press Washes'};
	$price{'Press Washes'} += $varnish_price{'Press Washes'};
	$price{'Press Wash Price'} = openprint::service::get_price( 'WashUp', undef, $Press );
	$price{'Press Wash Total'} = $price{'Press Washes'} * $price{'Press Wash Price'};

	if ( $plate_setup{'Plate Type'} ne 'Conventional' ) {
		$price{'Imposition MakeReady'} = openprint::service::get_price( 'ImpositionMakeReady','',$Press );
		$price{'Imposition Price'} = openprint::service::get_price( 'Imposition',$Imposition->imposition(),$Press);
	} # end if
	$price{'Imposition Total'} = $price{'Imposition MakeReady'} + $price{'Imposition Price'} * $$Imposition{imposition};

	my %RunStylePrice = openprint::service::get_price_object( $$Imposition{runstyle}.'Setup','',$Press );
	$price{'Runstyle Charge'} += $RunStylePrice{'Price'};

	$price{'Ink Mix Charge'} = $$pms_prices{'Ink Mix Charge'};
	my $setup_cost = $price{'Imposition Total'} + $price{'WorkTurn Dry Charge'} + $aqueous{'Setup'} + $$pms_prices{'Ink Mix Charge'} + $price{'Press Wash Total'} + $price{'Runstyle Charge'} + $varnish_price{'Setup'};
	$price{'Comparison Cost'} += $setup_cost;
#$openprint::log->debug("Comparison Cost: $price{'Comparison Cost'}");
	return \%price if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Run Charges' );
	$setup_cost += $press_setup;

	$price{'Setup Total'} = $setup_cost;
	$price{'Press Setup'} = $press_setup;

	my $run_cost = $run_price{'Price'};

	$price{'Impressions'} = $impressions;
	$price{'Impression Cost'} = $run_price{'Cost'};
	$price{'Impression Units'} = $run_price{'units'};
	$price{'Impression Price'} = $run_price{'Price'};

	$price{'Varnish'} = \%varnish_price;
	$run_cost += $varnish_price{'Run Total'};

	$price{'Aqueous'} = \%aqueous;
	if ( $aqueous{'Total'} ) {
		$run_cost += $aqueous{'Total'};
	} # end if
	$price{'Minimum Run Charge'} = openprint::service::get_price( 'PressRunChargeMinimum',undef,$Press );

	if ( $run_cost < $price{'Minimum Run Charge'} ) {
		$run_cost = $price{'Minimum Run Charge'};
	} # end if
	$price{'Run Total'} = $run_cost;


	$price{'Comparison Cost'} += $run_cost;
	return \%price if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Run Cost' );

	$price{'Ink Price'} = 0;
	foreach my $real_colour ( @colours ) {
		my $colour;
		if ( $real_colour =~ /Varnish/ ) {
			next;
		} elsif ( $real_colour =~ /(\w*) Spot Colour/ ) {
			$colour = $1;
		} elsif ( $real_colour =~ /PMS/ ) {
			$colour = 'PMS';
		} else { 
			$colour = $real_colour;
		} # end if
		my %ink_price;
		my $InkMaterial;
		if ( $$special_colours{$real_colour} ) {
#$openprint::log->debug("Special Colour: $real_colour $$inkCoverage{$real_colour}");
			$InkMaterial = new openprint::Material( $$special_colours{$real_colour}->{material_id} );
			%ink_price = $InkMaterial->get_price( undef, $Press );
		} # end if
		if ( ! %ink_price ) {
#$openprint::log->debug("Getting price for $colour Ink");
			if ( my @materials = openprint::Material::find('name'=>$colour.'Ink') ) {
				%ink_price = $materials[0]->get_price( undef, $Press );
			} # end if
		} # end if
		next if ! %ink_price;
		my $area = $Imposition->object_area() * $impressions * ($$inkCoverage{$real_colour}/100);
		my $grade = $Imposition->Paper()->grade();
		$grade = 4 if ! $grade;

		if ( lc $ink_price{'units'} eq 'per kg' ) {
			
			if ( sets::isin( $real_colour, $side_one_colours ) and sets::isin( $real_colour, $side_two_colours ) ) {
				$area /= 2;
			} # end if
			if ( (! $InkMaterial ) and my @materials = openprint::Material::find('name'=>$colour.'Ink') ) {
				$InkMaterial = $materials[0];
			} # end if
			if ( $InkMaterial ) {
				my $coverage = $InkMaterial->specification('Coverage', $grade);
				my $qty = sprintf('%.2f', $area/$coverage ) if $coverage;
				my %ink_price = $InkMaterial->get_price( $qty, $Press );
				$price{'Ink Price'} += $ink_price{'Price'} * $qty;
				$price{'Ink breakdown'} .= sprintf('%s : mileage: %d, %s * $%s%s=$%.2f<br/>', $real_colour, $coverage,$qty, $ink_price{'Price'},$ink_price{'units'},$ink_price{'Price'} * $qty);
			} # end if

		} elsif ( lc $ink_price{'units'} eq 'per square foot' ) {
			$area /= 144;
			my $p = $ink_price{'Price'} * $area;
			$price{'Ink Price'} += $p;
			$price{'Ink breakdown'} .= sprintf('%s breakdown: Grade: %d, %.2f sq feet  * $%s%s = $%.2f<br/>', $real_colour, $grade, $area, @ink_price{'Price','units'}, $p );
		} elsif ( lc $ink_price{'units'} eq 'per unit' ) {
			if ( sets::isin( $real_colour, $side_one_colours ) and sets::isin( $real_colour, $side_two_colours ) ) {
				$area /= 2;
			} # end if
			my $sheets_per_ink_unit = 750000;
			my $p = $ink_price{'Price'} * ($area/$sheets_per_ink_unit) / $$project{'print_sides'};
			$price{'Ink Price'} += $p;
			$price{'Ink breakdown'} .= sprintf('%s breakdown: %.2f sq feet * $%s%s / %d sheets per unit = $%.2f<br/>', $real_colour, $area, @ink_price{'Price','units'}, $sheets_per_ink_unit, $p );
		} elsif ( lc $ink_price{'units'} eq 'per square inch' ) {
			my $p = $ink_price{'Price'} * $area;
			$price{'Ink Price'} += $p;
			$price{'Ink breakdown'} .= sprintf('%s breakdown: Grade: %d, %d sq inches * $%s%s = $%.2f<br/>', $real_colour, $grade, $area, @ink_price{'Price','units'}, $p );
		} elsif ( lc $ink_price{'units'} eq 'per m' ) {
			$price{'Ink Price'} += $ink_price{'Price'} * $impressions/1000;
			$price{'Ink breakdown'} .= "\t".$real_colour . ' breakdown: ' . $impressions . " * $ink_price{'Price'}$ink_price{'units'} = " . $ink_price{'Price'} * $impressions/1000 . "<br/>";
		} else {
			#$run_price = 0;
			$openprint::log->error("Unknown units for Ink $colour: $ink_price{'units'}" . $Press->strid() );
		} # end if
	} # end foreach

	my $total_cost = $run_cost + $setup_cost + $plate_setup{'Plate Price'} * $plate_setup{'Plate Count'} + $price{'Ink Price'} + $varnish_price{'run_price'} + $varnish_price{'Material Total'} + $plate_setup{'Blank Price'} * $plate_setup{'Blank Plates'};
	$price{'Comparison Cost'} += $price{'Film Cost'} + $price{'Ink Price'} + $varnish_price{'run_price'} + $varnish_price{'Material Total'};
#$openprint::log->debug("Comparison Cost: $price{'Comparison Cost'}");
	return \%price if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Totals' );
	$price{'Total Cost'} = $total_cost;
	$price{'Total Cost'} += $price{'Paper Price'} if (! $$services{'Paper'}) and ($$specs{'rdbSuppliedStock'} ne 'Y');

	if ( ! $$specs{'no_stitching'} ) {
		if ( $$services{'SaddleStitching'} and $$specs{'txtSignatureType'} ne 'Cover Pages') {
			#my $starttime = gettimeofday();
			my $results = openprint::Estimating::Stitching::signature_calc( $Project, $service_index, $Imposition, $$project{'StitchingSpecs'}, $qty_index );
			if ( $$results{'Status'} eq 'uncalculated' ) {
				$price{'Stitching Breakdown'} .= "Stitching error: $$results{'alert'}<br/>";
				$price{'Comparison Cost'} += 1000000; # Can't stich this on
				$price{'Stitching Cost'} = 1000000;
			} else {
				$price{'StitchingImposition'} = $$results{'Imposition'};
				$price{'Stitching Breakdown'} .= "Stitching ($$results{'Imposition'} out) Price: \$$$results{'Price'}<br/>$$results{'alert'}<br/>";
				$price{'Stitching Cost'} = $$results{'Price'};
				$price{'Comparison Cost'} += $$results{'Price'};
			} # end if
			#$openprint::log->debug( 'Stitching Calc: ' . sprintf('%.4f', tv_interval( [$starttime])*1000) );

			return \%price if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Saddle Stitching' );
		} # end if
		if ( $$services{'LoopStitching'} ) {
		} # end if

		# Needed for Cutting
		$$specs{'StitchingImposition'.$qty_index} = $price{'StitchingImposition'};
	} # end if

# Now add in cutting costs to the comparison

	if ( $$project{'HasCutting'} ) {
		if ( ($Paper->type() ne 'Roll') and ($Paper->start_width() != $Paper->width() or $Paper->start_height() != $Paper->height() ) ) {
			#my $time = gettimeofday();
			my %cutting_results = openprint::Estimating::Cutting::signature_calc_stock_cutting( $openprint::log, $openprint::dbh, $openprint::variable, $Project, undef, $specs, $$project{'CuttingSpecs'}, $qty_index, $Paper );
			$price{'Cutting Breakdown'} .= "Stock Cutting Price: $cutting_results{'Price'} $$project{'CuttingSpecs'}{'alert'}<br/>";
			$price{'Comparison Cost'} += $cutting_results{'Price'};
#$openprint::log->debug("Elapsed stock cutting time:" . ( sprintf('%.4f', tv_interval( [$time])*1000) ) .' usecs' );
			return \%price if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Stock Cutting' );
		} # end if

		#my $time = gettimeofday();
		my %cutting_results = openprint::Estimating::Cutting::signature_calc( $openprint::log, $openprint::dbh, $openprint::variable, $Project, undef, $specs, $$project{'CuttingSpecs'}, $qty_index, $Paper );
#$openprint::log->debug("Elapsed cutting time:" . ( sprintf('%.4f', tv_interval( [$time])*1000) ) .' usecs' );
		if ( $$project{'CuttingSpecs'}{'Status'} eq 'uncalculated' ) {
			$price{'Cutting Breakdown'} .= "Cutting error: $$project{'CuttingSpecs'}{'alert'}<br/>";
		} else {
			$price{'Cutting Breakdown'} .= "Cutting Price: $cutting_results{'Price'}<br/>";
			#$price{'Cutting Breakdown'} .= $$project{'CuttingSpecs'}{'hdnBreakdown'.$qty_index}.'<br/>';
			$price{'Comparison Cost'} += $cutting_results{'Price'};
		} # end if

		return \%price if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Cutting' );
	} # end if

	if ( $$project{'HasScoring'} and $$project{'NeedScoring'} ) {
$openprint::log->debug("Scoring");
		my %scoring_results = openprint::Estimating::Scoring::signature_calc( $Project, @$project{'HasScoring','ScoringSpecs'}, $service_index, $specs, $qty_index );
$openprint::log->debug("Scoring REsults: $scoring_results{'Status'} $scoring_results{'Price'}");
		if ( $scoring_results{'Status'} eq 'uncalculated' ) {
			$price{'Scoring Breakdown'} .= "Scoring error: $scoring_results{'alert'} $$project{'ScoringSpecs'}{alert} " . $$project{'ScoringSpecs'}{'hdnBreakdown'.$qty_index} . '<br/>';
			$price{'Comparison Cost'} += 1000000; 
		} else {
			$price{'Scoring Breakdown'} .= "Scoring Price: $scoring_results{'Price'}<br/>";
			$price{'Comparison Cost'} += $scoring_results{'Price'};
		} # end if
		#return if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Scoring' );
	} # end if
	if ( $$project{'HasPerforating'} ) {
$openprint::log->debug("Perforating");
		my %perforating_results = openprint::Estimating::Perforating::signature_calc( $Project, @$project{'HasPerforating','PerforatingSpecs'}, $service_index, $specs, $qty_index );
		if ( $perforating_results{'Status'} eq 'uncalculated' ) {
			$price{'Perforating Breakdown'} .= "Perforating error: $perforating_results{'alert'} $$project{'PerforatingSpecs'}{alert} " . $$project{'PerforatingSpecs'}{'hdnBreakdown'.$qty_index} . '<br/>';
			$price{'Comparison Cost'} += 1000000; 
		} else {
			$price{'Perforating Breakdown'} .= "Perforating Price: $perforating_results{'Price'}<br/>";
			$price{'Comparison Cost'} += $perforating_results{'Price'};
		} # end if
		#return if check_price( $price_to_beat, \%price, $specs, $qty_index, $Imposition, 'Scoring' );
	} # end if
	if ( $$project{'HasUVCoating'} ) {
		my %uv_results = openprint::Estimating::UVCoating::signature_calc( $Project, @$project{'HasUVCoating','UVCoatingSpecs'}, $service_index, $specs, $qty_index, $Imposition );
		if ( $uv_results{'Status'} eq 'uncalculated' ) {
			$price{'UV Breakdown'} .= "UV error: $uv_results{'alert'} $$project{'UVCoatingSpecs'}{alert} " . $$project{'UVCoatingSpecs'}{'hdnBreakdown'.$qty_index} . '<br/>';
			$price{'Comparison Cost'} += 1000000; 
		} else {
			$price{'UVCoating Breakdown'} .= "UVCoating Price: $uv_results{'Total'}<br/>";
			$price{'Comparison Cost'} += $uv_results{'Total'};
		} # end if

	} # end if UVCoating

	$price{'complete'} = 1;
	return \%price;
} # end sub calc_price

sub select_presses {
# this function should return an list of the possible press for the job
# by elminating the presses that are not appropriate.

	my ( $project_index, $Paper, $specs, $side_one_colours, $side_two_colours ) = @_;
	#$log->debug("**** Start of select_press. Inputs: Project $project_index ****");

# we do not have to check Image Size here because the the imposition code will take care of that later on.
# it may be a little faster to eliminate the press now but i'm not sure.

# we do not need to do any Perfecting checks because imposition code will create or no create perfecting.

# Inline Perfing & Scoring is done as a sperate run, so it dosn't affect our printing press choice.

	my @good_presses;
	my $varnish = 0;
#$log->debug(" *** CHKECKING FOR VANISH *** ");
	foreach my $colour (@$side_one_colours, @$side_two_colours) {
		if ( $colour =~ /Varnish/ ) {
#$log->debug(" ** HAVE VARNISH **" );
			$varnish = 1;
		} # end if
	} # end if

	my ($project_type) = openprint::project::get_project_type( $openprint::log, $openprint::dbh, $project_index );
#$log->debug(" ** Current Project Types is: $project_type ** ");

	my @presses = openprint::Equipment::find( 'category'=>'Printing', 'UseInEstimating'=>'Y', 'order'=>'strid' );
	foreach my $Press ( @presses ) {
		my $press_id = $Press->strid();

		if ( $$specs{'ScreenType'} eq 'FM' and $Press->specification('FM Screening Capable') ne 'Y' ) {
			$openprint::log->debug("Press $press_id can't do FM Screening") if $debug;
			next;
		} # end if

		if ( $project_type eq 'Envelopes' and $Press->specification('Envelope Ready') ne 'Y' ) {
			$openprint::log->debug(" ** Press $press_id Failed Envelope Check **");
			next;
		} # end if

		if ( $Paper->calliper() > $Press->specification('Maximum Calliper', $Paper->grade() ) ) {
			$openprint::log->debug(" ** Press $press_id Failed Calliper Check **");
			next;
		} # end if

		if ( 
				(
				 ( $$specs{'rdbAqueousSideOne'} and ( $$specs{'rdbAqueousSideOne'} ne 'None' ) ) or
				 ( $$specs{'rdbAqueousSideTwo'} and ( $$specs{'rdbAqueousSideTwo'} ne 'None' ) ) 
				) and ( $Press->specification('Aqueous Coating') ne 'Y' )
		   ) {
			$openprint::log->debug(" ** Press $press_id Failed Aqueous Check (".$Press->specification('Aqueous Coating').")**");
			next;
		} # end if

		if ( $Press->specification('Printing Type') eq 'Digital' ) {
# Digital only support Process, no PMS, etc...
			if ( ( scalar @$side_one_colours == 1 ) and ( ! sets::isin( $$side_one_colours[0], ['Black', 'Black Spot Colour'] ) ) ) {
				$openprint::log->debug("Digital doesn't do non-black: $$side_one_colours[0]");
				next;
			} # end if
			if ( ( scalar @$side_two_colours == 1 ) and ( ! sets::isin( $$side_two_colours[0], ['Black', 'Black Spot Colour'] ) ) ) {
				$openprint::log->debug("Digital doesn't do non-black: $$side_two_colours[0]");
				next;
			} # end if

			if ( scalar @$side_one_colours > 1 and scalar @$side_one_colours < 4 ) {
				next;
			} # end if
			if ( scalar @$side_one_colours > 4 ) {
				next;
			} # end if
			if ( scalar @$side_two_colours > 1 and scalar @$side_two_colours < 4 ) {
				next;
			} # end if
			if ( scalar @$side_two_colours > 4 ) {
				next;
			} # end if
			if ( ( scalar @$side_one_colours == 4 ) and sets::intersection( @$side_one_colours, 'Cyan', 'Magenta', 'Yellow','Black' ) != 4 ) {
				next;
			} # end if
			if ( ( scalar @$side_two_colours == 4 ) and sets::intersection( @$side_two_colours, 'Cyan', 'Magenta', 'Yellow','Black' ) != 4 ) {
				next;
			} # end if
		} # end if

		if ( ( @$side_one_colours > $Press->specification('Number of Colours') or @$side_two_colours > $Press->specification('Number of Colours') ) and $Press->specification('Multipass', $Paper->gsm()) eq 'N' ) {
			$openprint::log->debug("Too many colours and no multipass") if $debug;
			next;
		} # end if

		if ( $varnish ) {
			if ( $Press->specification('Varnish Capable') ne 'Y' ) {
				$openprint::log->debug(" ** Press $press_id Failed Varnish Check **");
				next;
			} # end if
		} # end if

		push @good_presses, $Press;
	} # end while

#$log->debug("**** End of select_press. Selected Presses: @good_presses ****");
	return @good_presses;
} # end sub

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
		
	my %price = openprint::service::get_price_object( 'VarnishMakeReady', 1, $Press);
	if ( $price{'units'} eq 'Per Form' ) {
		my $previous_forms = 0;
 #$$specs{'PreviousForms'};
# Need to figure out how many similar forms we have
		foreach my $ss_id ( $Project->signatures() ) {
			next if $service_index and ($ss_id >= $service_index);
			my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
			$previous_forms += 1 if compare_signatures_runstyle( $specs, $sig_specs, $qty_index );
		} # end foreach
		#$openprint::log->debug("Previous Forms $previous_forms");
		#$$specs{'PreviousForms'} = $previous_forms;

		%price = openprint::service::get_price_object( 'VarnishMakeReady', $previous_forms + 1, $Press);
	} # end if
	$varnish_price{'Setup'} = $price{'Price'};


	if ( $$specs{'chkVarnishDryTrapSideOne'} or $$specs{'chkVarnishDryTrapSideTwo'} ) {
		%price = openprint::service::get_price_object( 'VarnishDryTrap', $impressions, $Press);
	} else {
		%price = openprint::service::get_price_object( 'VarnishInLine', $impressions, $Press);
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
				$varnish_price{'Material Price'} += $price{'Price'} * $qty;
				$varnish_price{'Material Total'} += $price{'Price'} * $qty;
			} # end if
		} # end if
	} # end foreach

#$log->debug(" **************** VARNISH RUN PRICE: $run_price * VS: $varnish_sides PS: $print_sides *********************");
	$varnish_price{'Press Washes'} = $varnish_sides;
	return %varnish_price;
} # end if


# Returns a price per image, which will later need to be multiplied by the imposition
sub get_special_colours_price {
	my ( $Press, $colours, $mixed_colours, $washed_colours, $special_colours, $qty_index ) = @_;
	my %price = ('Ink Mix Charge',0,'Press Washes',0);

	my %metallic_mix_price = openprint::service::get_price_object( 'MetallicInkMix','',$Press);
	my %pms_mix_price = openprint::service::get_price_object( 'PMSInkMix','',$Press);
	#my %wash_price = openprint::service::get_price_object( 'WashUp','',$Press);

	foreach my $key ( @{$colours} ) {
		next if sets::isin( $key, ['Cyan','Magenta','Yellow','Black','Cyan Spot Colour','Yellow Spot Colour','Magenta Spot Colour','Black Spot Colour'] );
		next if $key =~ /Varnish/;
		my $mix_price = \%pms_mix_price;

		if ( $$special_colours{$key} ) {
			$mix_price = \%metallic_mix_price;
		} # end if
		if ( ! $$mixed_colours{$key} ) {
			$price{'Ink Mix Charge'} += $$mix_price{'Price'};
		} # end if

# Washed_colours contains each colour used in the other signatures
		if ( ! $$washed_colours{$key.'-'.$Press->strid().'-'.$qty_index} ) {
			if ( $$special_colours{$key} ) {
				$price{'Press Washes'} += $$special_colours{$key}{washups};
			} else {
				$price{'Press Washes'} += 1;
			} # end if
		} # end if
#
	} # end foreach

# So here at the end, Total Run Price is the price of ink for a 1out 2-sided impression. If we multiply it by the imposition and # of sheets, then we should get the total cost of ink. 

	return \%price;
} # end sub get_special_colours_price

sub get_aqueous_price {
	my ( $log, $dbh, $variable, $impressions, $Press, $is_sheetwork, $qty_index, $Project, $service_index, $specs ) = @_;

	my %aqueous_price;

	my $aqueous_sides = 0;
	$aqueous_sides += 1 if $$specs{'rdbAqueousSideOne'} and ( $$specs{'rdbAqueousSideOne'} ne 'None' );
	$aqueous_sides += 1 if $$specs{'rdbAqueousSideTwo'} and ( $$specs{'rdbAqueousSideTwo'} ne 'None' );

	if ( $aqueous_sides > 0 ) {
		my $do_setup = 1;
# FInd out if there has been an aqueous setup already for a similar spread
		foreach my $index ( $Project->signatures() ) {
			next if $service_index and ($index >= $service_index);
			my $sig_specs = openprint::service::get_specs_ref( $Project, $index );
			if ( 
					( $$sig_specs{'rdbAqueousSideOne'} eq $$specs{'rdbAqueousSideOne'} )
					and ( $$sig_specs{'rdbAqueousSideTwo'} eq $$specs{'rdbAqueousSideTwo'} )
					and ( $$sig_specs{'ddmPress'.$qty_index} eq $Press->strid() )
			   ) {
				$do_setup = 0;
				last;
			} # end if
		} # end foreach
		if ( $do_setup ) {
			$aqueous_price{'Setup'} = openprint::service::get_price( 'AqueousMakeReady','',$Press);
			if ( $aqueous_sides == 1 and ! $is_sheetwork ) {
				$aqueous_price{'Setup'} += openprint::service::get_price( 'AqueousBlanketCut','',$Press);
			} # end if
		} # end if
# This will be * impressions /1000 later
		my %Price = openprint::service::get_price_object( 'Aqueous', $impressions, $Press);
		$aqueous_price{'Run Cost'} = $Price{'Price'};
		$aqueous_price{'Units'} = $Price{'units'};
		if ( sets::isin( lc $Price{'units'}, ['per m', 'per 1000','per 1000 impressions'] ) ) {
			$aqueous_price{'Total'} = $Price{'Price'} * ($impressions/1000);
		} else {
			$openprint::log->debug("Unknown units in Aqueous");
			$aqueous_price{'Total'} = $Price{'Price'};
		} # end if
	} # end if
	return %aqueous_price;
} # end sub get_aqueous_price

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

	if ( $Press->specification('Feed') eq 'Web' ) {
# A web does both sides at once, and cannot do multipass
		my %RunPrice = openprint::service::get_price_object( 'WebImpression', $impressions, $Press );
		$run_price{'units'} = $RunPrice{'units'};
		$running_price = $RunPrice{'Price'};
#$openprint::log->debug("Price: $running_price");
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

	$run_speed = $Press->specification('Press Standard Run Speed', $Imposition->paper()->gsm() ) if ! $run_speed;
	my $speed_mod = $Press->specification('Press Additional Run Speed',$Imposition->paper()->calliper());
#$openprint::log->warn("Press ".$Press->strid()." Calliper:". $Imposition->paper()->calliper()." ($running_price) ($run_price{'units'}) STD: ($run_speed) RUN ($speed_mod),  std/run: " . ( $speed_mod ? $run_speed/$speed_mod : $run_speed ) ) if $debug or 1;
	$run_speed = $run_speed / $speed_mod if $speed_mod;

	if ( sets::isin( lc $run_price{'units'}, ['per m','per 1000 impressions', 'per 1000'] ) ) {
		if ( $run_speed and $speed_mod ) {
			$running_price *= $run_speed;
		} # end if
#$log->warn(" ** FINAL  RUNNING PRICE $running_price **") if $debug or 1;
		$run_price{'Cost'} = $running_price;
		$run_price{'Price'} = ($run_price{'Cost'} * $impressions)/1000;
	} elsif ( lc $run_price{'units'} eq 'per hour' ) {
		if ( $run_speed ) {
# In Minutes, not hours
			$run_price{'RunHours'} = $impressions / $run_speed;
			$run_price{'RunTime'} = int ( 60 * $impressions / $run_speed );
		} # end if
		$run_price{'Cost'} = $running_price;
		$run_price{'Price'} = $running_price * $run_price{'RunHours'};
	} else {
		$openprint::log->debug("Unknown Units: $run_price{'units'}");
	} # end if
#$openprint::log->debug("Impresion price: $run_price{'Cost'} $run_price{'units'} = $run_price{'Price'}");
	return %run_price;
} # end sub

# This is called once perside, or just once for W&T
sub press_setup_cost {
	my ( $log, $dbh, $variable, $Press, $plate_change_qty, $plate_runs, $colours, $calliper, $specs, $qty_index, $Project, $service_index, $Imposition ) = @_;

	my $setup_count = 0;

	foreach my $colour ( @$colours ) {
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
	if ( ! ( %Price = openprint::service::get_price_object( 'PressUnitMakeReady'.$Imposition->runstyle(), undef, $Press ) ) ) {
		%Price = openprint::service::get_price_object( 'PressUnitMakeReady', undef, $Press );
	} # end if
	if ( $Price{'units'} eq 'Stock Calliper - Per Plate' ) {
		%Price = openprint::service::get_price_object( 'PressUnitMakeReady', $calliper, $Press);
		$Price{'Total'} = $Price{'Price'} * $setup_count;
	} elsif ( $Price{'units'} eq 'Per Form' ) {

		my $previous_forms = 0;
# Need to figure out how many similar forms we have
		foreach my $ss_id ( $Project->signatures() ) {
#$openprint::log->debug("Previous Forms: $previous_forms, $ss_id, $service_index ");
			next if $service_index and ($ss_id >= $service_index);
			my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
			$previous_forms += 1 if compare_signatures_runstyle( $specs, $sig_specs, $qty_index );
#$openprint::log->debug("Previous Forms: $previous_forms");
		} # end foreach

		%Price = openprint::service::get_price_object( 'PressUnitMakeReady', $previous_forms + 1, $Press);
		$Price{'Total'} = $Price{'Price'};
	} else { # Per Unit
		if ( ! ( %Price = openprint::service::get_price_object( 'PressUnitMakeReady'.$Imposition->runstyle(), $setup_count, $Press ) ) ) {
			%Price = openprint::service::get_price_object( 'PressUnitMakeReady', $setup_count, $Press );
		} # end if
		$Price{'Total'} = $Price{'Price'} * $setup_count;
	} # end if
	if ( $Price{'units'} =~ /Per Run/i ) {
		$Price{'Total'} *= $plate_runs if $plate_runs;
		$Price{'Total'} *= $plate_change_qty if $plate_change_qty;
	} # end if
	my %PlateSetupPrice = openprint::service::get_price_object( 'PlateMakeReady', undef, $Press );
	if ( %PlateSetupPrice ) {
		if ( lc $PlateSetupPrice{'units'} eq 'per hour' ) {
			my $time = $Press->specification('Plate Setup Time');
			$time *= ($setup_count + $plate_change_qty);
			$time *= $plate_runs if $plate_runs;
			$time /= 60;
			#$time /= 2;
			$Price{'Plate Total'} = $PlateSetupPrice{'Price'} * $time;
			$Price{'Total'} += $PlateSetupPrice{'Price'} * $time;
		} else {
			$openprint::log->error("Invalid units in PlateSetupPrice ($PlateSetupPrice{'units'})");
		} # end if
	} # end if
	
	$Price{'Unit Count'} = $setup_count;
	return \%Price;
} # end sub press_setup_cost

# plate_setup_cost 
#
# $used_plates => # of plates used in other signatures, for quantity discounts
#

sub plate_setup_cost {
	my ( $Imposition, $Press, $sheet_area, $impressions, $colours, $specs, $qty_index ) = @_;

	my $plate_count = 0;
	my $non_process_colours = 0;

	foreach my $colour ( @$colours ) {
		$plate_count += 1;
		$non_process_colours += 1 if ! sets::isin( $colour, ['Cyan','Magenta','Yellow','Black','Cyan Spot Colour','Yellow Spot Colour','Magenta Spot Colour','Black Spot Colour'] );
	} # end foreach colour

	my $plate_count_before_changes = $plate_count;
	$plate_count += $$specs{'txtPlateChangeQuantity'.$qty_index} if $$specs{'txtPlateChangeQuantity'.$qty_index} > 0;

	my ($plate_type,$plate_size,$max_impressions) = (
			$Press->specification('Plate Type'),
			$Press->specification('Plate Size'),
			$Press->specification('Maximum Plate Impressions'),
			);
	$max_impressions = int($max_impressions);
	$max_impressions = 250000 if ! $max_impressions;
	my $plate_runs = ceil($impressions/$max_impressions);

#$log->debug("** GETTTING PLATE SIZE FOR: $press : SIZE ($plate_size) TYPE ($plate_type) COUNT ($plate_count) RUNS($plate_runs)*$impressions*$max_impressions") if $debug or 1;
	$plate_count *= $plate_runs;
	my $plate_id = $plate_size . '-' . $plate_type . 'Plate';
#$log->debug("Previous Plates: $used_plates");


	my ( $plate_price_qty ) = $plate_count + $$specs{'PreviousPlates'.$qty_index};
# becuase the material id for plates is the PlateSetter we do not send the press to get a plate price or it will not find it.
		
	my %plate_price;
	if ( my @materials = openprint::Material::find( 'name'=>$plate_id.$Imposition->runstyle() ) ) {
		%plate_price = $materials[0]->get_price( $plate_price_qty, undef );
	} elsif ( my @materials = openprint::Material::find( 'name'=>$plate_id ) ) {
		%plate_price = $materials[0]->get_price( $plate_price_qty, undef );
	} # end if

	my $film_cost = 0;
	if ( $plate_type eq 'Conventional' ) {
		$film_cost = openprint::service::get_price( 'Film', $sheet_area * $plate_price_qty, undef );
		$film_cost *= $sheet_area * $plate_price_qty;
	} # end if 
#$log->debug("Plate Count:: $plate_count");
	my %setup_cost = (
			'Plate Count', $plate_count, 
			'Plate Price', $plate_price{'Price'},
			'Plate Type', $plate_type,
			'Film Cost',$film_cost,
			'Plate Runs', $plate_runs,
			);

	# Some presses like P1's Web press need blank plates for the unused colours.  You can get a gazillion impressions for them though, so you only need 1 set.
	my $blanks_needed;
	if ( $Press->specification( 'Require Blank Plates' ) eq 'Y' ) {
		$blanks_needed = ($Press->specification('Number of Colours') - @$colours) - $$specs{'PreviousBlankPlates'.$qty_index};
		$setup_cost{'Blank Plates'} = $blanks_needed;
		if ( my @materials = openprint::Material::find( 'name'=>'Blank'.$plate_id ) ) {
			my %blank_plate_price = $materials[0]->get_price( $blanks_needed+$$specs{'PreviousBlankPlates'.$qty_index}, undef );
			$setup_cost{'Blank Price'} = $blank_plate_price{'Price'};
		} # end if
	} elsif ( $Press->specification( 'Require Blank Plates' ) eq 'When Non-Process' ) {
		if ( $non_process_colours ) {
			$blanks_needed = ($Press->specification('Number of Colours') - @$colours) - $$specs{'PreviousBlankPlates'.$qty_index};
			$setup_cost{'Blank Plates'} = $blanks_needed;
			if ( my @materials = openprint::Material::find( 'name'=>'Blank'.$plate_id ) ) {
				my %blank_plate_price = $materials[0]->get_price( $blanks_needed+$$specs{'PreviousBlankPlates'.$qty_index}, undef );
				$setup_cost{'Blank Price'} = $blank_plate_price{'Price'};
			} # end if
		} # end if
	} # end if
	return %setup_cost;
} # end sub plate_setup

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
			} elsif ( $colour eq 'Overall Varnish Gloss' ) {
# Overall Varnishes become Spots when Work & Turn and not Overall on Both Sides
				if ( ! sets::isin('Spot Varnish Gloss', \@colours ) ) {
					push @filtered_colours, $colour;
				} # end if
			} elsif ( $colour eq 'Overall Varnish Matte' ) {
# Overall Varnishes become Spots when Work & Turn and not Overall on Both Sides
				if ( ! sets::isin('Spot Varnish Matte', \@colours ) ) {
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
		foreach my $key ( 'ddmRunStyle', 'ddmPress','PageQuantity' ) {
			if ( $$sig1{$key.$q_i} ne $$sig2{$key.$q_i} ) {
				#$openprint::log->debug("Not the same $key $$sig1{$key.$q_i} $$sig2{$key.$q_i} $$sig1{SignatureIndex} $$sig2{SignatureIndex}");
				return 0;

			} # end if
		} # end if
	} # end foreach q_i
	foreach my $key (
			'txtWidth','txtHeight',
			'chkProcessColourSideOne', 'chkProcessColourSideTwo',
			'chkCyanSideOne','chkMagentaSideOne','chkYellowSideOne','chkBlackSideOne',
			'chkCyanSideTwo','chkMagentaSideTwo','chkYellowSideTwo','chkBlackSideTwo',
			'txtSpecialSideOneColour1', 'txtSpecialSideOneColourInkPercent1',
			'txtSpecialSideOneColour2', 'txtSpecialSideOneColourInkPercent2',
			'txtSpecialSideOneColour3', 'txtSpecialSideOneColourInkPercent3',
			'txtSpecialSideOneColour4', 'txtSpecialSideOneColourInkPercent4',
			'txtSpecialSideOneColour5', 'txtSpecialSideOneColourInkPercent5',
			'txtSpecialSideOneColour6', 'txtSpecialSideOneColourInkPercent6',
			'txtSpecialSideOneColour7', 'txtSpecialSideOneColourInkPercent7',
			'txtSpecialSideOneColour8', 'txtSpecialSideOneColourInkPercent8',
			'txtSpecialSideTwoColour1', 'txtSpecialSideTwoColourInkPercent1',
			'txtSpecialSideTwoColour2', 'txtSpecialSideTwoColourInkPercent2',
			'txtSpecialSideTwoColour3', 'txtSpecialSideTwoColourInkPercent3',
			'txtSpecialSideTwoColour4', 'txtSpecialSideTwoColourInkPercent4',
			'txtSpecialSideTwoColour5', 'txtSpecialSideTwoColourInkPercent5',
			'txtSpecialSideTwoColour6', 'txtSpecialSideTwoColourInkPercent6',
			'txtSpecialSideTwoColour7', 'txtSpecialSideTwoColourInkPercent7',
			'txtSpecialSideTwoColour8', 'txtSpecialSideTwoColourInkPercent8',
			'rdbAqueousSideOne',
			'rdbAqueousSideTwo',
			'chkBleedLeft','chkBleedRight','chkBleedTop','chkBleedBottom','ddmBleedSize',
			) {
				if ($$sig1{$key} ne $$sig2{$key} ) {
#$openprint::log->debug("Not the same $key");
					return 0;
				} # end if
			} # end foreach
	return 1;
}
# compares two signature services in terms of their inputs, and returns true if equal, false if not
sub compare_signatures {
	my ( $sig1, $sig2, $qty_index ) = @_;
	return 0 if ! compare_signatures_runstyle( $sig1, $sig2, $qty_index );
#foreach my $q_i ( $qty_index ? ( $qty_index ) : ( 1 .. 3 ) ) {
##foreach my $key ( 'ddmRunStyle', 'ddmPress' ) {
#return 0 if $$sig1{$key.$q_i} ne $$sig2{$key.$q_i};
#} # end if
#} # end foreach q_i
	foreach my $key (
			'CustomStockPrice','txtCustomMWeight','CustomStockPriceUnits','txtStockGSM',
			'txtSpecificStockBrand','txtSpecificStockFinish','txtSpecificStockColour',
			'txtSpecificStockWidth', 'txtSpecificStockHeight',
			'ddmStockBrand', 'ddmStockFinish', 'ddmStockColour', 'ddmStockWeight',
			'rdbSuppliedStock','rdbSpecificStock',
			) {
		return 0 if $$sig1{$key} ne $$sig2{$key};
	} # end foreach

	return 1;
} # end sub compare_signatures

sub runtime {
	my ( $Project, $specs ) = @_;

    my ( $qty_index ) = $Project->ordered_quantity_index();
	my %time;

	if ( ! $$specs{'UsePress'} ) {
		$$specs{'UsePress'} = $$specs{'ddmPress'.$qty_index};
	} # end if

	my @Equipment = openprint::Equipment::find( 'strid'=>$$specs{'UsePress'} );
	my $Equipment = shift @Equipment;
	my @side_one_colours = openprint::Estimating::Printing::get_colours( $specs, 'SideOne' );
	my @side_two_colours = openprint::Estimating::Printing::get_colours( $specs, 'SideTwo' );
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
	#$time{'Setup'} += 60*$Equipment->specification('Plate Setup Time') ;

	my $run_speed = $Equipment->specification( 'Press Additional Run Speed',$$specs{'txtSpecificStockCalliper'} );
	my $std_runspeed = $Equipment->specification('Press Standard Run Speed');

	if ( $std_runspeed ) {
		if ( $run_speed ) {
			$time{'Run'} += int( ( 60 * $$specs{'hdnImpressionQuantity'.$qty_index} / $std_runspeed ) * ( $std_runspeed / $run_speed ) );
		} else {
			$time{'Run'} += int ( 60 * $$specs{'hdnImpressionQuantity'.$qty_index} / $std_runspeed );
		} # end if
	} # end if
	$time{'Total'} = $time{'Setup'} + $time{'Run'};
	return \%time;
} # end sub runtime

sub get_weight {
	my ( $Project, $specs, $qty_index ) = @_;

	my $Paper = openprint::Paper::load_from_signature( $Project, $specs, $qty_index );
	my $sig_weight = $$specs{'txtWidth'} * $$specs{'txtHeight'} * $Paper->wpsi();
	if ( $$specs{'PageQuantity'.$qty_index} ) {
		# 
		$sig_weight *= $$specs{'PageQuantity'.$qty_index}/$$specs{'txtSpreadSize'};
	} # end if
	if ( $$specs{'PageQuantity'} ) {
		# For Scratch Pads
		$sig_weight *= $$specs{'PageQuantity'};
	} # end if
	return $sig_weight;
} # end sub get_weight

1;

__END__
~	   
