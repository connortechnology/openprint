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

package openprint::Estimating::Cutting;
use POSIX qw{ ceil };

use strict;

require openprint::project;
require openprint::Equipment;
require openprint::service;
require openprint::Service;
require openprint::print;

require sql;

my $debug = 1;

my @equipment;
my @stitchers;

my @variables = (
        'txtPrice1', 'txtPrice2', 'txtPrice3',
		'Markup1','Markup2','Markup3',
		'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
        'MPrice1', 'MPrice2', 'MPrice3',
        'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
        'txtRunTime1', 'txtRunTime2', 'txtRunTime3',
		'txtFinishedCalliper',
        );

sub variables {
	my @v = @variables;
	my $p_id = shift;

	my $Project = new openprint::Project( $p_id );
	foreach my $s_s_id ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		push @v, "txtStockCalliper-$$specs{'SignatureIndex'}";
		push @v, "chkOverrideCalliper-$$specs{'SignatureIndex'}";
		push @v, "txtAdditionalCuts$$specs{'SignatureIndex'}";
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, "txtCalculatedCuts-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "ddmEquipment-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "ddmStockCutEquipment-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "chkOverrideStockCutEquipment-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "chkOverrideCalculatedCuts-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "chkboxVerticalCuts-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "txtboxVerticalCuts-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "chkboxHorizontalCuts-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "txtboxHorizontalCuts-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "chkboxDVerticalCuts-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "txtboxDVerticalCuts-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "chkboxDHorizontalCuts-$$specs{'SignatureIndex'}-$qty_index";
			push @v, "txtboxDHorizontalCuts-$$specs{'SignatureIndex'}-$qty_index";
		} # end foreach
	} # end foreach

    return @v;
} # end sub variables

sub signature_needs {
	my ( $Project, $sig_specs ) = @_;

	my $services = $Project->services();

	if ( $Project->Type()->name() eq 'Envelopes' ) {
        $openprint::log->debug(" ** Project Type is Envelopes, Cutting Service is NOT needed ** ");
		return 0;
	} # end if 

    if ( $$services{'NoBindery'} ) {
        $openprint::log->debug(" ** Project is marked as No bindery, Cutting not needed ! ** ");
        return 0;
    } # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
#$openprint::log->debug("Cutting sig needs: imp: " .  $$specs{'txtImposition'.$qty_index} );
#$openprint::log->debug("Cutting sig needs: stock: " . join('x', @$specs{'hdnSuppliedStockWidth'.$qty_index,'hdnSuppliedStockHeight'.$qty_index} ) );
#$openprint::log->debug("Cutting sig needs: ssize: " . join('x', @$specs{'txtWidth','txtHeight'} ) );
		if ( $$sig_specs{'txtImposition'.$qty_index} > 1 ) {
			return 1;
		} # end if
		if ( ! (
					(
					 $$sig_specs{'hdnSuppliedStockWidth'.$qty_index} == $$sig_specs{'txtWidth'} 
					 and $$sig_specs{'hdnSuppliedStockHeight'.$qty_index} == $$sig_specs{'txtHeight'}
					) or (
						$$sig_specs{'hdnSuppliedStockWidth'.$qty_index} == $$sig_specs{'txtHeight'}
						and $$sig_specs{'hdnSuppliedStockHeight'.$qty_index} == $$sig_specs{'txtWidth'}
						)
			   ) ) {
			return 1;
		} # end if
	} # end foreach

	foreach my $service_name ( 'PlasticCoil', 'MetalCoil', 'PlasticComb', 'Cerlox', 'DoubleLoopWire' ) {
		if ( $$services{$service_name} ) {
			return 1;
		} # end if
	} # end foreach

	return 0;
} # end sub signature_needs

# A function that is smart enough to return true if the project needs cutting, and false if it doesn't.
sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;
	my $Project = new openprint::Project( $project_index );

	my $services = $Project->services();

	if ( $$services{'NoBindery'} ) {
        $log->debug(" ** Project is marked as No bindery, Cutting not needed ! ** ");
		return 0;
	} # end if

	foreach my $service_name ( 'PlasticCoil', 'MetalCoil', 'PlasticComb', 'Cerlox', 'DoubleLoopWire' ) {
		if ( $$services{$service_name} ) {
			return 1;
		} # end if
	} # end foreach

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		if ( signature_needs( $Project, $specs ) ) {
			return 1;
		} # end if
	} # end foreach
	$log->debug("CUTTING NOT NEEDED!");
	return 0;
} # end sub neccessary

sub signature_calc_stock_cutting {
	my ( $Project, $service_index, $sig_specs, $specs, $qty_index, $Paper, $Imposition ) = @_;

	my %results = (
			'Status'	=> 'calculated',
			);
	my $services = $Project->services();
#$openprint::log->debug("Stock Cutting Paper: " . $Paper->to_string() );
# Add cutting the sheet prior to printing
	return %results if ( ! ( $Paper->width() and $Paper->height() ) );
	return %results if ($Paper->width() == $Paper->start_width()) and ($Paper->height() == $Paper->start_height() );
	return %results if ( exists $$sig_specs{'PageQuantity'.$qty_index} and ! $$sig_specs{'PageQuantity'.$qty_index} );

	if ( ! @equipment ) {
		@equipment = openprint::Equipment::find( 'Specifications' => {'Cutting Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
	} # end if
	@stitchers = openprint::Equipment::find( 'Specifications' => {'Stitching Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)') if ! @stitchers;
	my @my_equipment;

	if ( $$specs{"chkOverrideStockCutEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		$openprint::log->debug("Overriding Equipment! " . $$specs{"ddmStockCutEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"});
		@my_equipment = ( new openprint::Equipment( @$specs{"ddmStockCutEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) );
	} else {
		@my_equipment = sets::exclude( \@stitchers, \@equipment );
	} # end if

	if ( ! @my_equipment ) {
		$results{'alert'} = 'We have no cutting equipment.<br/>';
		$results{'Status'} = 'uncalculated';
		return %results;
	} # end if

	my $signature_index = $$sig_specs{'SignatureIndex'};
	$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $signature_index: $$sig_specs{'txtServiceDescription'}:<br/>" if $$sig_specs{'txtServiceDescription'};

# Grab the Calliper
	if ( $$specs{"chkOverrideCalliper-$signature_index"} ne 'Y' ) {
		$$specs{"txtStockCalliper-$signature_index"} = $Paper->calliper();
	} # end if

	my $calliper = $$specs{"txtStockCalliper-$signature_index"};
	if ( ! $calliper ) {
		$results{'alert'} .= "Calliper is unknown for signature $signature_index.";
		$results{'Status'} = 'uncalculated';
		return %results;
	} # end if
	if ( ! $$Imposition{'imposition'} ) {
		$$specs{'hdnBreakdown'.$qty_index} .= 'No Imposition:<br/>';
		$results{'alert'} .= "No imposition for signature $signature_index";	
		$results{'Status'} = 'calculated';
		return %results;
	} # end if

	if ( ($Paper->start_width() >= $Paper->width()) and ($Paper->start_height() >= $Paper->height()) ) {
		@$specs{"txtSuppliedStockWidth-$signature_index-$qty_index", "txtSuppliedStockHeight-$signature_index-$qty_index",
			"txtSheetSizeWidth-$signature_index-$qty_index", "txtSheetSizeHeight-$signature_index-$qty_index"} =
				( 
				 ( $Paper->start_width() ? $Paper->start_width() : $Paper->width() ),
				 ( $Paper->start_height() ? $Paper->start_height() : $Paper->height() ), 
				 $Paper->width(), 
				 $Paper->height()
				);
	} else {
		@$specs{"txtSuppliedStockWidth-$signature_index-$qty_index", "txtSuppliedStockHeight-$signature_index-$qty_index",
			"txtSheetSizeWidth-$signature_index-$qty_index", "txtSheetSizeHeight-$signature_index-$qty_index"} =
				( 
				 ( $Paper->start_width() ? $Paper->start_width() : $Paper->height() ),
				 ( $Paper->start_height() ? $Paper->start_height() : $Paper->width() ), 
				 $Paper->height(), 
				 $Paper->width()
				);
	} # end if

	$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Cutting prior to printing: %sx%s -> %sx%s<br/>', @$specs{"txtSuppliedStockWidth-$signature_index-$qty_index", "txtSuppliedStockHeight-$signature_index-$qty_index",
        "txtSheetSizeWidth-$signature_index-$qty_index", "txtSheetSizeHeight-$signature_index-$qty_index"} );

	my $bestPrice = undef;
	my $mprice = 0;
	my $bestEquipment;
# Has to happen on normal cutters
	foreach my $Equipment ( @my_equipment ) {
		$$specs{'hdnBreakdown'.$qty_index} .= 'Equipment: '.$Equipment->name().':';
		if ( $$services{'NoOfflineBindery'} and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$$specs{'hdnBreakdown'.$qty_index} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
			next;
		} # end if

		my $reason = $Equipment->fits( @$specs{"txtSuppliedStockWidth-$signature_index-$qty_index","txtSuppliedStockHeight-$signature_index-$qty_index"} );
		$$specs{'hdnBreakdown'.$qty_index} .= $reason . '<br/>';
		next if $reason;

		my $liftDepth = $Equipment->specification( 'Maximum Lift Depth', undef );
		next if ! $liftDepth;
#		my $sheets = int( $$sig_specs{'txtPressSheetQty'.$qty_index} / ( ($$specs{"txtSuppliedStockWidth-$signature_index-$qty_index"}*$$specs{"txtSuppliedStockHeight-$signature_index-$qty_index"}) / ($sheet_width*$sheet_height) ) );

		my $width_cuts = int( $$specs{"txtSuppliedStockWidth-$signature_index-$qty_index"} / $$specs{"txtSheetSizeWidth-$signature_index-$qty_index"} );
		my $height_cuts = int( $$specs{"txtSuppliedStockHeight-$signature_index-$qty_index"} / $$specs{"txtSheetSizeHeight-$signature_index-$qty_index"} );
		my $sheets = int( $$sig_specs{'txtPressSheetQty'.$qty_index} / ($width_cuts * $height_cuts) );
		if ( $width_cuts == 1 and $$specs{"txtSuppliedStockWidth-$signature_index-$qty_index"} != $$specs{"txtSheetSizeWidth-$signature_index-$qty_index"} ) {
			$width_cuts += 1;
		} # end if
		if ( $height_cuts == 1 and $$specs{"txtSuppliedStockHeight-$signature_index-$qty_index"} != $$specs{"txtSheetSizeWidth-$signature_index-$qty_index"} ) {
			$height_cuts += 1;
		} # end if
#$openprint::log->debug( $$specs{"txtSuppliedStockWidth-$signature_index-$qty_index"} . '/' . $sheet_width );
#$openprint::log->debug( $$specs{"txtSuppliedStockHeight-$signature_index-$qty_index"} . '/' . $sheet_height );
#$openprint::log->debug( "$sheets = $width_cuts $height_cuts" );
		my %ServicePrice = openprint::service::get_price_object( 'Cutting', $sheets, $Equipment );
		my $price = 0;
		foreach my $cuts ( $width_cuts -1, $height_cuts-1 ) {
			next if ! $cuts;
$openprint::log->warn("Negative CUTS!") if $cuts < 1;
			my $runs = ceil( $sheets*$calliper/$liftDepth );
			$price += ( $runs * $cuts * $ServicePrice{'Price'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Cutting %d sheets into %d sheets in %d runs: %.2f<br/>', $sheets, $sheets*($cuts+1), $runs, $price );
			$sheets *= $cuts+1;
		} # end foreach
		my $setupCost = openprint::service::get_price( 'CuttingMakeReady', undef, $Equipment );
		my $totalPrice = $setupCost + $price;
		my %cleaning;
		if ( $Paper->bladecleaning() ) {
			%cleaning = openprint::service::get_price_object( 'Blade Cleaning', undef, $Equipment );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Blade Cleaning: %.2f<br/>', $cleaning{'Price'} );
			$totalPrice += $cleaning{'Price'};
		} # end if
		if ( ( ! defined $bestPrice ) or ( $bestPrice > $totalPrice ) ) {
			$mprice = $price + $cleaning{'Price'};
			$bestPrice = $totalPrice;
			$bestEquipment = $Equipment;
		} # end if
	} # end for each equipment
	$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};	
	my %results = (
			'Price' 	=> sprintf($openprint::config{'ProjectMoneyFormat'}, $bestPrice ),
			'MPrice'	=> ($mprice/$$specs{'txtQuantity'.$qty_index})*1000,
			'Equipment'	=> $bestEquipment,
			);
	if ( ! $bestEquipment ) {
		$results{'alert'} .= 'No equipment found for stock cutting.<br/>';
		$results{'Status'} = 'uncalculated';
	} # end if
	return %results;
} # end sub signature_calc_stock_cutting

sub signature_calc_folding_cutting {
	my ( $log, $dbh, $variable, $Project, $service_index, $sig_specs, $specs, $qty_index, $Paper, $I, $fold_specs ) = @_;

	my %results = (
			'Status'	=> 'calculated',
			);

	my $services = $Project->services();
	return %results if ! $$services{'Folding'};

#$openprint::log->debug("Loading Paper from signature in signature_calc_folding_cutting");
	$Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index ) if ! $Paper;
	if ( ! $I ) {
		$I = new openprint::Imposition();
		$I->Paper( $Paper );
		$I->load( $sig_specs, $qty_index );
	} # end if
	return %results if ! $I->imposition();
	$results{'Status'} = 'uncalculated';

	@equipment = openprint::Equipment::find( 'Specifications' => {'Cutting Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)') if ! @equipment;
	my @my_equipment;

	if ( $$specs{"chkOverrideFoldCutEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		$log->debug("Overriding Equipment! " . $$specs{"ddmFoldCutEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"});
		@my_equipment = ( new openprint::Equipment( @$specs{"ddmFoldCutEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) );
	} else {
		@my_equipment = @equipment;
	} # end if

	if ( ! @my_equipment ) {
		$results{'alert'} = 'We have no cutting equipment.<br/>';
		return %results;
	} # end if

	# Consider Cutting before folding, compare pages on signature verses folds, for example 24->16+8
	$fold_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] ) if ! $fold_specs;
	my %folds;
	foreach my $fold ( keys %openprint::Estimating::Folding::fold_types ) {
		if ( $$fold_specs{"$fold-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"} ) {
			if ( $fold =~ /(\d*)PageSignatureFold/ ) {
				$folds{$1} = $$fold_specs{"$fold-Qty-$$sig_specs{'SignatureIndex'}-$qty_index"};
			} # end if
		} # end if
	} # end foreach fold
	my $folding_cuts = keys %folds;
	$$specs{'hdnBreakdown'.$qty_index} .= sprintf("Cutting prior to folding: \%d -> \%s<br/>", $I->pages(), join(',',keys %folds ) );
	if ( $folding_cuts <= 1 ) {
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Not needed<br/>' );
		$results{'Status'} = 'calculated';
		return %results;
	} # end if

	my $signature_index = $$sig_specs{'SignatureIndex'};
	$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $signature_index: $$sig_specs{'txtServiceDescription'}:<br/>" if $$sig_specs{'txtServiceDescription'};

# Grab the Calliper
	if ( $$specs{"chkOverrideCalliper-$signature_index"} ne 'Y' ) {
		$$specs{"txtStockCalliper-$signature_index"} = $Paper->calliper();
	} # end if

	my $bestPrice = undef;
	my $bestEquipment;
# Has to happen on normal cutters
	foreach my $Equipment ( @my_equipment ) {
		next if $Equipment->specification('Type') eq 'Stitcher';
		if ( $$services{'NoOfflineBindery'} and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$$specs{'hdnBreakdown'.$qty_index} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
			next;
		} # end if

		$$specs{'hdnBreakdown'.$qty_index} .= "\tEquipment: ".$Equipment->name().':';

		my $reason = $Equipment->fits( $I->paper()->width(), $I->paper()->height() );
		$$specs{'hdnBreakdown'.$qty_index} .= $reason . '<br/>';
		next if $reason;

		my $liftDepth = $Equipment->specification( 'Maximum Lift Depth', undef );
		next if ! $liftDepth;

		my $sheets = ceil( $$sig_specs{'txtQuantity'.$qty_index} / $I->imposition() );
		my %ServicePrice = openprint::service::get_price_object( 'Cutting', $sheets, $Equipment );
		my $price = 0;
		my $runs = ceil( $sheets*$Paper->calliper()/$liftDepth );
		$price += ( $runs * $folding_cuts * $ServicePrice{'Price'} );
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\tCutting \%d sheets in %d runs: %.2f<br/>", $sheets, $runs, $price );
		my $setupCost = openprint::service::get_price( 'CuttingMakeReady', undef, $Equipment );
		my $totalPrice = $setupCost + $price;
		if ( $Paper->bladecleaning() ) {
			my %cleaning = openprint::service::get_price_object( 'Blade Cleaning', undef, $Equipment );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf("Blade Cleaning: %.2f<br/>", $cleaning{'Price'} );
			$totalPrice += $cleaning{'Price'};
		} # end if
		if ( ( ! defined $bestPrice ) or ( $bestPrice > $totalPrice ) ) {
			$bestPrice = $totalPrice;
			$bestEquipment = $Equipment;
		} # end if
	} # end for each equipment
	$results{'Status'}		= $bestEquipment ? 'calculated' : 'uncalculated';
	$results{'Price'}		= sprintf($openprint::config{'ProjectMoneyFormat'}, $bestPrice );
	$results{'MPrice'}		= ($bestPrice/$$specs{'txtQuantity'.$qty_index})*1000;
	$results{'Equipment'}	= $bestEquipment;
	return %results;
} # end sub signature_calc_folding_cutting

sub signature_calc {
	my ( $Project, $service_index, $sig_specs, $specs, $qty_index, $Paper, $I ) = @_;

	my %results = (
			'Status'	=> 'calculated',
			);
	my $services = $Project->services();

	my @my_equipment;

	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@my_equipment = ( new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) );
	} else {
		if ( ! @equipment ) {
			my @capabilities = ('Y','When Printing','When Folding');
			if ( $$services{'SaddleStitching'} or $$services{'LoopStitching'} ) {
				push @capabilities, 'When Stitching';
			} # end if
			@equipment = openprint::Equipment::find( 'Specifications' => {'Cutting Capable'=>\@capabilities}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
		} # end if
		@my_equipment = @equipment;
	} # end if

	if ( ! @my_equipment ) {
		$results{'alert'} = 'We have no cutting equipment.<br/>';
		$results{'Status'} = 'uncalculated';
		return %results;
	} # end if
	my $signature_index = $$sig_specs{'SignatureIndex'};

	$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};	
	if ( ! $$specs{"txtQuantity$qty_index"} ) {
		$results{'alert'} = 'No quantity entered.<br/>';
		$results{'Status'} = 'uncalculated';
		return %results;
	} # end if

	my $sheets = $$specs{"txtQuantity$qty_index"};
	$sheets *= $$specs{'txtNameQuantity'} if $$specs{'txtNameQuantity'};
	$sheets *= $$sig_specs{'PageQuantity'} if $$sig_specs{'PageQuantity'};
# Grab the Calliper
	if ( $$specs{"chkOverrideCalliper-$signature_index"} ne 'Y' ) {
		$$specs{"txtStockCalliper-$signature_index"} = $Paper->calliper();
	} # end if

	my $calliper = $$specs{"txtStockCalliper-$signature_index"};
	if ( ! $calliper ) {
		$openprint::log->debug("**** NO Calliper ****");
		$results{'alert'} .= "Calliper is unknown for signature $signature_index.<br/>";
		$results{'Status'} = 'uncalculated';
		return %results;
	} # end if

	my $stitching_imposition;
	if ( $$services{'SaddleStitching'} ) {
		my $stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'SaddleStitching'}[0] );
		$stitching_imposition = $$stitching_specs{'Imposition'.$qty_index};
	} elsif ( $$services{'LoopStitching'} ) {
		my $stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'LoopStitching'}[0] );
		$stitching_imposition = $$stitching_specs{'Imposition'.$qty_index};
	} elsif ( $$services{'PerfectBound'} ) {
		my $stitching_specs = openprint::service::get_specs_ref( $Project, $$services{'PerfectBound'}[0] );
		$stitching_imposition = $$stitching_specs{'Imposition'.$qty_index};
	} # end if

	my $folding_imposition = new openprint::Imposition();
	my $folding_specs;
	if ( $$services{'Folding'} ) {
		$folding_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );
		$folding_imposition->columns( $$folding_specs{"FoldColumns-$$sig_specs{'SignatureIndex'}-$qty_index-1"} );
		$folding_imposition->rows( $$folding_specs{"FoldRows-$$sig_specs{'SignatureIndex'}-$qty_index-1"} );
		#imposition is automatic
	} else {
		$folding_imposition->columns( 1 );
		$folding_imposition->rows( 1 );
	} # end if

	if ( $I->image_orientation() eq 'Horizontal' ) {
		$stitching_imposition = $$I{'columns'} if $stitching_imposition > $$I{'columns'};
	} else {
		$stitching_imposition = $$I{'rows'} if $stitching_imposition > $$I{'rows'};
	} # end if
	
	my ( $sheet_width, $sheet_height ) = ($Paper->width(), $Paper->height() );

# calculate cuts
	my $vertical_cuts = 0;
	$$specs{'hdnBreakdown'.$qty_index} .= 'Regular Cuts: calliper:' . $calliper.'<br/>';

# interior vertical cuts = $sig_specs{'hdnImpositionColumns'}-1
	if ( exists $$sig_specs{'txtSignatureType'} ) {
		# Regular book signatures will be trimmed by the stitcher, so we only need 1 cut per imposition
		# but if we are cutting into smaller signatures, then we need more cutting
#$openprint::log->debug("Sitching $stitching_imposition to $$sig_specs{'txtImposition'.$qty_index}");

		if ( $stitching_imposition and ( $$I{'image_orientation'} eq 'Horizontal' ) ) {
			$vertical_cuts += int ($$I{'columns'} / $stitching_imposition)-1;
		} else {
			$vertical_cuts += $$I{'columns'}-1;
		} # end if
		if ( $$sig_specs{'txtSignatureType'} eq 'Cover Pages' ) {
#$openprint::log->warn('Negative Vertical Sig Cuts') if $vertical_cuts < 0;
			if ( $$I{'image_orientation'} eq 'Horizontal' ) {
				# Assume head to head at all times - head trim
				if ( $$sig_specs{'chkBleedTop'} ) {
					$vertical_cuts += int ( $$I{'columns'}/2 );
				} # end if
			} # end if
		} # end if
	} else {
# The 2 is for outside edge cuts
		my $columns =  $$folding_imposition{columns} ? $$I{'columns'} / $$folding_imposition{columns} : $$I{'columns'};
		$vertical_cuts += 1+$columns;# = 2+$$I{'columns'}-1
		if ( 
				( $$I{'image_orientation'} eq 'Vertical' and ( $$sig_specs{'chkBleedLeft'} or $$sig_specs{'chkBleedRight'} ) ) or
				( $$I{'image_orientation'} eq 'Horizontal' and ( $$sig_specs{'chkBleedTop'} or $$sig_specs{'chkBleedBottom'} ) )
		   ) {
			$vertical_cuts += $columns-1;
		} # end if
# Splitting the folded products is done on the folder for free
		#if ( ( $$folding_imposition{'columns'} > 1 ) and ( $$folding_imposition{'columns'} < $$I{'columns'} ) ) {
			#$vertical_cuts += ($$I{'columns'} / $$folding_imposition{'columns'})-1;
		#} # end if
	} # end if

# interior horizontal cuts = $sig_specs{'hdnImpositionRows'}-1 with bleeds
	my $horizontal_cuts = 0;
	if ( exists $$sig_specs{'txtSignatureType'} ) {
		if ( $stitching_imposition and ( $I->image_orientation() eq 'Vertical' ) ) {
			$horizontal_cuts += int ($$I{'rows'} / $stitching_imposition)-1; 
		} else {
			$horizontal_cuts += $$I{'rows'}-1;
		} # end if
		if ( $$sig_specs{'txtSignatureType'} eq 'Cover Pages' ) {
#$openprint::log->warn('Negative Horizontal Sig Cuts') if $horizontal_cuts < 0;
			if ( $$I{'image_orientation'} eq 'Vertical' ) {
				if ( $$sig_specs{'chkBleedTop'} ) {
					$horizontal_cuts += int( $$I{'rows'}/2);
				} # end if
			} # end if
		} # end if
	} else {
		my $rows = $$folding_imposition{rows} ? $$I{'rows'}/$$folding_imposition{rows} : $$I{'rows'};
		$horizontal_cuts += 1 + $rows;#2 + $$I{'rows'}-1
		if ( $$sig_specs{'ddmBleedSize'.$qty_index} and ( 
					( $$I{'image_orientation'} eq 'Horizontal' and ( $$sig_specs{'chkBleedLeft'} or $$sig_specs{'chkBleedRight'} ) ) or
					( $$I{'image_orientation'} eq 'Vertical' and ( $$sig_specs{'chkBleedTop'} or $$sig_specs{'chkBleedBottom'} ) ) )
		   ) {
			$horizontal_cuts += $rows-1;
		} # end if
# Splitting the folded products is done on the folder for free
		#if ( ($$folding_imposition{'rows'} > 1 ) and ( $$folding_imposition{'rows'} < $$I{'rows'} ) ) {
			#$horizontal_cuts += ($$I{'rows'} / $$folding_imposition{'rows'})-1;
		#} # end if
	} # end if

	my $dutch_vertical_cuts = 0;
	my $dutch_horizontal_cuts = 0;
	# Dutch cuts don't happen on books
	if ( ! exists $$sig_specs{'txtSignatureType'} ) {

		# Now consider Dutch cuts
		if ( $$I{'dutch_columns'} and $$I{'dutch_rows'} ) {
			$dutch_vertical_cuts += 1 + $$I{'dutch_columns'};
			$dutch_horizontal_cuts += $$I{'dutch_rows'}; # +1 - 1
			if ( ( $$sig_specs{'chkBleedTop'} and $$sig_specs{'chkBleedBottom'} ) or ($$sig_specs{'chkBleedLeft'} and $$sig_specs{'chkBleedRight'} ) ) {
				$dutch_horizontal_cuts += 1;
			} # end if
			if ( 
					( $$I{'image_orientation'} eq 'Vertical' and ( $$sig_specs{'chkBleedTop'} or $$sig_specs{'chkBleedBottom'} ) ) or
					( $$I{'image_orientation'} eq 'Horizontal' and ( $$sig_specs{'chkBleedLeft'} or $$sig_specs{'chkBleedRight'} ) )
			   ) {
				$dutch_vertical_cuts += $$I{'dutch_columns'}-1;
			} # end if
			if ( 
					( $$I{'image_orientation'} eq 'Horizontal' and ( $$sig_specs{'chkBleedTop'} or $$sig_specs{'chkBleedBottom'} ) ) or
					( $$I{'image_orientation'} eq 'Vertical' and ( $$sig_specs{'chkBleedLeft'} or $$sig_specs{'chkBleedRight'} ) )
			   ) {
				$dutch_horizontal_cuts += $$I{'dutch_rows'}-1;
			} # end if
		} # end if dutch imposition
	} # end if exists signaturetype

#following lines add on 16-july-2008
	if ( $$specs{'chkboxVerticalCuts-'.$signature_index.'-'.$qty_index} eq 'Y' ) {
		$vertical_cuts = $$specs{"txtboxVerticalCuts-$signature_index-$qty_index"};
	} else {
		$$specs{"txtboxVerticalCuts-$signature_index-$qty_index"} = $vertical_cuts;
	}

#following lines add on 16-july-2008
	if ( $$specs{'chkboxHorizontalCuts-'.$signature_index.'-'.$qty_index} eq 'Y' ) {
		$horizontal_cuts = $$specs{"txtboxHorizontalCuts-$signature_index-$qty_index"};
	} else {
		$$specs{"txtboxHorizontalCuts-$signature_index-$qty_index"} = $horizontal_cuts;
	}

	if ( $$specs{'chkboxDVerticalCuts-'.$signature_index.'-'.$qty_index} eq 'Y' ) {
		$dutch_vertical_cuts = $$specs{"txtboxDVerticalCuts-$signature_index-$qty_index"};
	} else {
		$$specs{"txtboxDVerticalCuts-$signature_index-$qty_index"} = $dutch_vertical_cuts;
	}

	if ( $$specs{'chkboxDHorizontalCuts-'.$signature_index.'-'.$qty_index} eq 'Y' ) {
		$dutch_horizontal_cuts = $$specs{"txtboxDHorizontalCuts-$signature_index-$qty_index"};
	} else {
		$$specs{"txtboxDHorizontalCuts-$signature_index-$qty_index"} = $dutch_horizontal_cuts;
	}

	if ( $$specs{'chkOverrideCalculatedCuts-'.$signature_index.'-'.$qty_index} ne 'Y' ) {
		$$specs{"txtCalculatedCuts-$signature_index-$qty_index"} = $vertical_cuts + $horizontal_cuts + $dutch_vertical_cuts + $dutch_horizontal_cuts;
	}
	my $cuts = $$specs{"txtCalculatedCuts-$signature_index-$qty_index"};

	my $bestPrice = undef;
	my $bestM = 0;
	my $bestEquipment;
	foreach my $Equipment ( @my_equipment ) {
		next if ! $Equipment->id();
		$$specs{'hdnBreakdown'.$qty_index} .= 'Equipment ' . $Equipment->name() .':';
		if ( $$services{'NoOfflineBindery'} and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$$specs{'hdnBreakdown'.$qty_index} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
			next;
		} # end if
		if ( $Equipment->specification('Cutting Capable') eq 'When Folding' ) {
			if ( ! $$services{'Folding'} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Not folding<br/>';
				next;
			} # end if

			my $folding_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );
			if( $$folding_specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ne $Equipment->id() ) {
				my $Folder = new openprint::Equipment( $$folding_specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
				$$specs{'hdnBreakdown'.$qty_index} .= 'Not folding on ' . $Equipment->strid(). ' Folder is ' . $Folder->strid() . '<br/>';
				next;
			} # end if
		} elsif ( ( $Equipment->specification('Cutting Capable') eq 'When Printing' ) and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$$specs{'hdnBreakdown'.$qty_index} .= 'Not printing on ' . $Equipment->strid();
			next;
		} # end if

		my $liftDepth;
		if ( $$services{'UVCoating'} and openprint::Estimating::UVCoating::signature_needs( $Project, $sig_specs ) ) {
			$liftDepth = $Equipment->specification( 'Maximum Lift Depth with UVCoating' );
		} # end if
		$liftDepth = $Equipment->specification( 'Maximum Lift Depth' ) if ! $liftDepth;
		$$specs{'hdnBreakdown'.$qty_index} .= "(Lift: $liftDepth)<br/>";
		my $totalPrice = 0;
		my $mprice = 0;

		if ( my $reason = $Equipment->fits( $sheet_width, $sheet_height ) ) {
			$$specs{'hdnBreakdown'.$qty_index} .= $reason . '<br/>';
			next;
		} # end if

		my %ServicePrice = openprint::service::get_price_object( 'Cutting', undef, $Equipment );
		if ( $ServicePrice{'units'} eq 'Per Cut' ) {
			%ServicePrice = openprint::service::get_price_object( 'Cutting', $$specs{"txtQuantity$qty_index"} * $cuts, $Equipment );
		} else {
			%ServicePrice = openprint::service::get_price_object( 'Cutting', $$specs{"txtQuantity$qty_index"}, $Equipment );
		} # end if
        #if ( $ServicePrice{'units'} eq 'Per Inch' ) {

		my $price;
		my $sheets = ceil( $$sig_specs{'txtQuantity'.$qty_index} / $$I{'imposition'} );
		$sheets *= $$sig_specs{'PageQuantity'} if $$sig_specs{'PageQuantity'};
		my $runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : 1;
		$$specs{'hdnBreakdown'.$qty_index} .= '# of cuts: ' . $cuts . ' => ' .($cuts * $sheets) . '<br/>';

		if ( $vertical_cuts > $horizontal_cuts ) {
			$price = ( $runs * $vertical_cuts * $ServicePrice{'Price'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Vertical cuts on %d sheets in %d runs: %.2f<br/>", $vertical_cuts, $sheets, $runs, $price );
			$totalPrice += $price;
			if ( $openprint::config{'Dumb Cutting'} ne 'Y' ) {
				$sheets *= $$I{'columns'};
				$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : 1;
			} # end if
			$price = ( $runs * $horizontal_cuts * $ServicePrice{'Price'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Horizontal cuts on %d sheets in %d runs: %.2f<br/>", $horizontal_cuts, $sheets, $runs, $price );
			$totalPrice += $price;
		} else {
			$price = ( $runs * $horizontal_cuts * $ServicePrice{'Price'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Horizontal cuts on %d sheets in %d runs: %.2f<br/>", $horizontal_cuts, $sheets, $runs, $price );
			$totalPrice += $price;
			if ( $openprint::config{'Dumb Cutting'} ne 'Y' ) {
				$sheets *= $$I{'rows'};
				$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : 1;
			} # end if
			$price = ( $runs * $vertical_cuts * $ServicePrice{'Price'} );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Vertical cuts on %d sheets in %d runs: %.2f<br/>", $vertical_cuts, $sheets, $runs, $price );
			$totalPrice += $price;
		} # end if

		if ( $dutch_vertical_cuts or $dutch_horizontal_cuts ) {
			$$specs{'hdnBreakdown'.$qty_index} .= "\tDutch Cuts: ";

			$sheets = ceil( $$sig_specs{'txtQuantity'.$qty_index} / $$I{'imposition'} );
			$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : 1;

			if ( $vertical_cuts > $horizontal_cuts ) {
				$price = ( $runs * $vertical_cuts * $ServicePrice{'Price'} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Vertical cuts on %d sheets in %d runs: %.2f<br/>", $vertical_cuts, $sheets, $runs, $price );
				$totalPrice += $price;
				if ( $openprint::config{'Dumb Cutting'} ne 'Y' ) {
					$sheets *= $$I{'dutch_columns'};
					$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : 1;
				} # end if
				$price = ( $runs * $horizontal_cuts * $ServicePrice{'Price'} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Horizontal cuts on %d sheets in %d runs: %.2f<br/>", $horizontal_cuts, $sheets, $runs, $price );
				$totalPrice += $price;
			} else {
				$price = ( $runs * $horizontal_cuts * $ServicePrice{'Price'} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Horizontal cuts on %d sheets in %d runs: %.2f<br/>", $horizontal_cuts, $sheets, $runs, $price );
				$totalPrice += $price;
				if ( $openprint::config{'Dumb Cutting'} ne 'Y' ) {
					$sheets *= $$I{'dutch_rows'};
					$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : 1;
				} # end if
				$price = ( $runs * $vertical_cuts * $ServicePrice{'Price'} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Vertical cuts on %d sheets in %d runs: %.2f<br/>", $vertical_cuts, $sheets, $runs, $price );
				$totalPrice += $price;
			} # end if

			
			if ( $dutch_vertical_cuts or $dutch_horizontal_cuts ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "\tDutch Cuts: ";

				$sheets = ceil( $$sig_specs{'txtQuantity'.$qty_index} / $$I{'imposition'} );
				$sheets *= $$sig_specs{'PageQuantity'} if $$sig_specs{'PageQuantity'};
				$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : 1;

				if ( $dutch_vertical_cuts > $dutch_horizontal_cuts ) {
					$price = ( $runs * $dutch_vertical_cuts * $ServicePrice{'Price'} );
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Vertical cuts on %d sheets in %d runs: %.2f<br/>", $dutch_vertical_cuts, $sheets, $runs, $price );
					$totalPrice += $price;
					if ( $openprint::config{'Dumb Cutting'} ne 'Y' ) {
						$sheets *= $$I{'dutch_columns'};
						$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : 1;
					} # end if
					$price = ( $runs * $dutch_horizontal_cuts * $ServicePrice{'Price'} );

					$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Horizontal cuts on %d sheets in %d runs: %.2f<br/>", $dutch_horizontal_cuts, $sheets, $runs, $price );
					$totalPrice += $price;
				} else {
					$price = ( $runs * $dutch_horizontal_cuts * $ServicePrice{'Price'} );
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Horizontal cuts on %d sheets in %d runs: %.2f<br/>", $dutch_horizontal_cuts, $sheets, $runs, $price );
					$totalPrice += $price;
					if ( $openprint::config{'Dumb Cutting'} ne 'Y' ) {
						$sheets *= $$I{'dutch_rows'};
						$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : 1;
					} # end if
					$price = ( $runs * $dutch_vertical_cuts * $ServicePrice{'Price'} );

					$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\t%d Vertical cuts on %d sheets in %d runs: %.2f<br/>", $dutch_vertical_cuts, $sheets, $runs, $price );
					$totalPrice += $price;
				} # end if
			} # end if
		} # end if

		if ( ( ! $$specs{"txtAdditionalCuts$signature_index"} ) and $$sig_specs{'txtPressSheetComboItems'} ) {
			$$specs{"txtAdditionalCuts$signature_index"} = $$sig_specs{'txtPressSheetComboItems'};
		} # end if

		if ( $$specs{"txtAdditionalCuts$signature_index"} ) {
			$sheets = ceil( $$sig_specs{'txtQuantity'.$qty_index} / $$I{'imposition'} );
			my $runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : 1;
			my $price = ( $runs * $$specs{"txtAdditionalCuts$signature_index"} * $ServicePrice{'Price'} );
			$$specs{'hdnBreakdown'.$qty_index} .= 'Additional cuts:<br/>';
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('%d cuts on %d sheets: $%.2f<br/>', $$specs{"txtAdditionalCuts$signature_index"}, $sheets, $price );
			$totalPrice += $price;
		} # end if

		$mprice = $totalPrice;

		if ( $cuts ) {
			my $setup = openprint::service::get_price( 'CuttingMakeReady', undef, $Equipment );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Make Ready: $%.2f<br/>', $setup );
			$totalPrice += $setup;
			if ( $Paper->bladecleaning() ) {
				my %cleaning = openprint::service::get_price_object( 'Blade Cleaning', undef, $Equipment );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Blade Cleaning: $%.2f<br/>', $cleaning{'Price'} );
				$totalPrice += $cleaning{'Price'};
				$mprice += $cleaning{'Price'};
			} # end if
		} # end if
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Total: $%.2f<br/>', $totalPrice );
		if ( ( ! $bestEquipment ) or ( $bestPrice > $totalPrice ) ) {
			$bestM = $mprice;
			$bestPrice = $totalPrice;
			$bestEquipment = $Equipment;
		} # end if
	} # end for each equipment

	my %results = (
			'Status'	=> $bestEquipment ? 'calculated' : 'uncalculated',
			'Price'		=> $bestPrice,
			'MPrice'	=> ($bestM/$$specs{'txtQuantity'.$qty_index})*1000,
			'Equipment'	=> $bestEquipment,
			);
	return %results;
} # end sub signature_calc

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	$$specs{'Status'} = 'calculated';

	if ( ! $$specs{'txtNameQuantity'} ) {
		$$specs{'txtNameQuantity'} = 1;
	} # end if

	my $Project = new openprint::Project( $project_index );
	@equipment = openprint::Equipment::find( 'Specifications' => {'Cutting Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
	push @equipment, openprint::Equipment::find( 'Specifications' => {'Cutting Capable'=>'When Printing'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
	push @equipment, openprint::Equipment::find( 'Specifications' => {'Cutting Capable'=>'When Folding'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
	@stitchers = openprint::Equipment::find( 'Specifications' => {'Stitching Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
	if ( ! @equipment ) {
		$$specs{'alert'} = 'We have no cutting equipment.<br/>';
		$$specs{'Status'} = 'uncalculated';
		return;
	} # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		next if ! int($$specs{"txtQuantity$qty_index"});

		$$specs{'hdnBreakdown'.$qty_index} = '';
		my $price;
		my $mprice;

# For the non-book case, this devolves into the printing service
		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			my $signature_index = $$sig_specs{'SignatureIndex'};
			$$specs{'hdnBreakdown'.$qty_index} .= "<br/>Signature: $signature_index ";
			my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			my $Imposition = new openprint::Imposition();
			$Imposition->paper( $Paper );
			$Imposition->load( $sig_specs, $qty_index );
			next if ! $Imposition->imposition();

			@variables = sets::union( @variables, ( "txtStockCalliper-$signature_index",
						"txtCalculatedCuts-$signature_index-$qty_index", "chkOverrideCalculatedCuts-$signature_index-$qty_index",
						"txtStockCuts-$signature_index-$qty_index", "chkOverrideCalculatedCuts-$signature_index-$qty_index",
						"txtAdditionalCuts$signature_index" ) 
					);


			@variables = sets::union( @variables, ( "txtSuppliedStockWidth-$signature_index-$qty_index",
						"txtSuppliedStockHeight-$signature_index-$qty_index",
						"txtSheetSizeWidth-$signature_index-$qty_index",
						"txtSheetSizeHeight-$signature_index-$qty_index",
						)	);
#added on 16-july-2008
			@variables = sets::union( @variables, ( "txtboxVerticalCuts-$signature_index-$qty_index",
						"chkboxVerticalCuts-$signature_index-$qty_index",
						"txtboxHorizontalCuts-$signature_index-$qty_index",
						"chkboxHorizontalCuts-$signature_index-$qty_index",
						"txtboxDVerticalCuts-$signature_index-$qty_index",
						"chkboxDVerticalCuts-$signature_index-$qty_index",
						"txtboxDHorizontalCuts-$signature_index-$qty_index",
						"chkboxDHorizontalCuts-$signature_index-$qty_index",
						)	);

			if ( ( $$sig_specs{'StockType'.$qty_index} ne 'Roll' ) and ( $$sig_specs{"hdnSuppliedStockWidth$qty_index"} != $$sig_specs{'StockWidth'.$qty_index} or $$sig_specs{"hdnSuppliedStockHeight$qty_index"} != $$sig_specs{'StockHeight'.$qty_index} ) ) {
				my %results = signature_calc_stock_cutting( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Paper, $Imposition );
				$$specs{"ddmStockCutEquipment-$signature_index-$qty_index"} = $results{'Equipment'} ? $results{'Equipment'}->id() : '';
				$$specs{"txtStockCutPrice-$signature_index-$qty_index"} = $results{'Price'};
				$price += $results{'Price'};
				$mprice += $results{'MPrice'};
				$$specs{'Status'} = 'uncalculated' if $results{'Status'} eq 'uncalculated';
				$$specs{'alert'} .= $results{'alert'};
			} # end if

			# Folding
if ( 1 ) {
			my %results = signature_calc_folding_cutting( $log, $dbh, $variable, $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Paper, $Imposition );
			$$specs{"ddmFoldCutEquipment-$signature_index-$qty_index"} = $results{'Equipment'} ? $results{'Equipment'}->id() : '';
			$$specs{"txtFoldCutPrice-$signature_index-$qty_index"} = $results{'Price'};
			$price += $results{'Price'};
			$mprice += $results{'MPrice'};
			$$specs{'Status'} = 'uncalculated' if $results{'Status'} eq 'uncalculated';
			$$specs{'alert'} .= $results{'alert'};
$openprint::log->warn("Status from sig_calc_folding: $results{'Status'}");
} # end if

			my %results = signature_calc( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Paper, $Imposition );
			$$specs{'Status'} = 'uncalculated' if $results{'Status'} eq 'uncalculated';
			$$specs{'alert'} .= $results{'alert'};

			my $minCharge = openprint::service::get_price( 'CuttingChargeMinimum', undef, $results{'Equipment'} );
			$results{'Price'} = $minCharge if $results{'Price'} and ($results{'Price'} < $minCharge);

			#$$specs{"ddmEquipment$qty_index"} = $results{'Equipment'};
			$$specs{"txtRegularCutPrice-$signature_index-$qty_index"} = sprintf('%.2f', $results{'Price'} );
			$price += $results{'Price'};
			$mprice += $results{'MPrice'};
			$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Equipment'} ? $results{'Equipment'}->id() : '';
		} # end foreach signature_index

		if ( $$specs{"OverridePrice$qty_index"} eq 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price*(1+$$specs{'Markup'.$qty_index}/100) );
		} # end if
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $mprice *(1+$$specs{'Markup'.$qty_index}/100) );
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $price/$$specs{"txtQuantity$qty_index"} );

	} # end foreach quantity
	return $$specs{'Status'};
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my @possible_equipment = openprint::Equipment::find( 'Specifications' => {'Cutting Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
	@{$$variable{'StockCutEquipmentArray'}} = map { $_->id(), $_->name() } @possible_equipment;

	push @possible_equipment, openprint::Equipment::find( 'Specifications' => {'Cutting Capable'=>'When Printing'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
	push @possible_equipment, openprint::Equipment::find( 'Specifications' => {'Cutting Capable'=>'When Folding'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
	my @stitchers = openprint::Equipment::find( 'Specifications' => {'Stitching Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');
	@{$$variable{'EquipmentArray'}} = map { $_->id(), $_->name() } @possible_equipment;


	my $Project = new openprint::Project( $project_index );

	@{$$variable{'CuttingGroups'}} = ();

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		push @{$$variable{'CuttingGroups'}}, $signature_service_index, @$specs{'SignatureIndex','txtServiceDescription'};
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			next if $$specs{'StockType'.$qty_index} eq 'Roll';
			@$variable{"txtSuppliedStockWidth-$$specs{'SignatureIndex'}-$qty_index", "txtSuppliedStockHeight-$$specs{'SignatureIndex'}-$qty_index",
				"txtSheetSizeWidth-$$specs{'SignatureIndex'}-$qty_index", "txtSheetSizeHeight-$$specs{'SignatureIndex'}-$qty_index"} =
				@$specs{"hdnSuppliedStockWidth$qty_index","hdnSuppliedStockHeight$qty_index","StockWidth$qty_index","StockHeight$qty_index"};

		} # end foreach
#, $signature_qty;

	} # end foreach
	if ( @{$$variable{'CuttingGroups'}} == 0 ) {
# this will display the first group of cutting fields for projects that dont' have a printing service.
		push @{$$variable{'CuttingGroups'}}, 0;
	} # end if

} # end sub display

sub jdf {
	my ( $doc, $Project, $sig_id ) = @_;

	my $sig_specs = openprint::service::get_specs_ref( $Project->id(), $sig_id );

	my $JDF = $doc->createElement('JDF');
	$JDF->setAttribute('ID','Cutting'.$sig_id);
	$JDF->setAttribute('Type','Cutting');
	$JDF->setAttribute('Status','Waiting');
	my $ResourcePool = $JDF->appendElement( $doc->createElement('ResourcePool') );
	my $Media = $ResourcePool->appendElement( $doc->createElement('Media') );
	$Media->setAttribute( 'ID', 'Paper'.$sig_id );
	$Media->setAttribute( 'Class', 'Consumable' );
	$Media->setAttribute( 'Status', 'Available' );
	$Media->setAttribute( 'Brand', $$sig_specs{'ddmStockBrand'} );
	$Media->setAttribute( 'DescriptiveName', join(' ', @$sig_specs{'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight','StockWidth'.$Project->ordered_quantity_index(),$Project->ordered_quantity_index()} ) );
	$Media->setAttribute( 'Dimension', join(' ',
                Math::Units::convert($$sig_specs{'StockWidth'.$Project->ordered_quantity_index()},'in','mm'),
                Math::Units::convert($$sig_specs{'StockHeight'.$Project->ordered_quantity_index()},'in','mm'),
			) );
	$Media->setAttribute( 'GrainDirection', 'LongEdge' );
	$Media->setAttribute( 'MediaType', 'Paper' );
	$Media->setAttribute( 'MediaUnit', 'Sheet' );
	$Media->setAttribute( 'Grade', '1' );
	$Media->setAttribute( 'Thickness', Math::Units::convert($$sig_specs{'SpecificStockCalliper'},'in','mm') );
	$Media->setAttribute( 'Weight', Math::Units::convert($$sig_specs{'txtMWeight'..$Project->ordered_quantity_index()}/1000,'lb','g') );


	my $InputComponent = $ResourcePool->appendElement( $doc->createElement('Component') );
	$InputComponent->setAttribute( 'ID', 'CuttingInput'.$sig_id );
	$InputComponent->setAttribute( 'Class','Quantity' );
	$InputComponent->setAttribute( 'Status','Available' );
	$InputComponent->setAttribute( 'ComponentType','Sheet' );
	$InputComponent->setAttribute( 'Dimensions',join(' ', 
				Math::Units::convert($$sig_specs{'StockWidth'.$Project->ordered_quantity_index()},'in','mm'),
				Math::Units::convert($$sig_specs{'StockHeight'.$Project->ordered_quantity_index()},'in','mm'),
				Math::Units::convert($$sig_specs{'SpecificStockCalliper'},'in','mm'),
				) );
	my $CuttingParams = $ResourcePool->appendElement( $doc->createElement('CuttingParams') );
	$CuttingParams->setAttribute('ID','CPM'.$sig_id);
	$CuttingParams->setAttribute('Class','Parameter');
	$CuttingParams->setAttribute('Status','Available');

	my $OutputComponent = $ResourcePool->appendElement( $doc->createElement('Component') );
	$OutputComponent->setAttribute( 'ID', 'CuttingOutput'.$sig_id );
	$OutputComponent->setAttribute( 'Class','Quantity' );
	$OutputComponent->setAttribute( 'Status','Available' );
	$OutputComponent->setAttribute( 'ComponentType','Block' );
	$OutputComponent->setAttribute( 'Dimensions',join(' ', 
				Math::Units::convert($$sig_specs{'txtWidth'},'in','mm'),
				Math::Units::convert($$sig_specs{'txtHeight'},'in','mm'),
				Math::Units::convert($$sig_specs{'SpecificStockCalliper'},'in','mm'),
				) );

	# Need Media, Input Component, CuttingParams, Output Component
	my $ResourceLinkPool = $JDF->appendElement( $doc->createElement('ResourceLinkPool') );
	
	return $JDF;
} # end sub jdf

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	#$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
	return '';
} # end sub summary

sub runtime {
    my ( $p_id, $s_id, $specs, $qty_index ) = @_;
    return 0 if ! $$specs{'ddmEquipment'.$qty_index};

	my $runtime = 0;
	my @Equipment = openprint::Equipment::find('strid'=>$$specs{'ddmEquipment'.$qty_index});
	if ( @Equipment ) {	
		my $makeready = $Equipment[0]->specification( 'Make Ready Time' );
		my $runspeed = $Equipment[0]->specification( 'Cutting Time' );
		my $Project = new openprint::Project( $p_id );
		foreach my $s_s_id ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
			$runtime += $$specs{"txtCalculatedCuts$$sig_specs{'SignatureIndex'}"} * ( $makeready + $runspeed);
			$runtime += $$specs{"txtAdditionalCuts$$sig_specs{'SignatureIndex'}"} * ( $makeready + $runspeed);
		} # end foreach
	
	} # end if
	return $runtime;
} # end sub runtime
sub save {
} # end sub save


1;
__END__
