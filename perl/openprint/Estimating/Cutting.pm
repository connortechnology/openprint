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

use strict;
use warnings;
package openprint::Estimating::Cutting;
use POSIX qw{ ceil };

use openprint ();
use vars qw( $log $dbh %config );
*log = \$openprint::log;
*dbh = \$openprint::dbh;
*config = \%openprint::config;

require openprint::Equipment;
require openprint::service;
require openprint::Service;

use constant DEBUG => 0;

my @equipment;
my @PreFoldingEquipment;

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

	my $Project = new openprint::Project( $_[0] );
	foreach my $s_s_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		my $form = $$sig_specs{SignatureIndex};
		push @v, "txtAdditionalCuts$form";
		push @v, map { ( "txtCalculatedCuts-$form-$_",
			 "ddmEquipment-$form-$_",
			 "chkOverrideCalculatedCuts-$form-$_",
			 "txtVerticalCuts-$form-$_",
			 "txtHorizontalCuts-$form-$_",
			 "txtDVerticalCuts-$form-$_",
			 "txtDHorizontalCuts-$form-$_",
			 "FoldingCuts-$form-$_",
			 "FoldingEquipment-$form-$_",
			 "OverrideFoldingCuts-$form-$_",
			 "OverrideFoldingEquipment-$form-$_",
			 "ddmStockCutEquipment-$form-$_",
			 "chkOverrideStockCutEquipment-$form-$_",
		) } $Project->quantity_indexes();
	} # end foreach

    return @v;
} # end sub variables

sub outputs { 
} # end sub outputs

sub no_outputs {
} # end sub no_outputs

sub has_overrides {
    my ( $Project, $service_id, $specs ) = @_;
    $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

    my @v;
    foreach my $s_s_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		my $form = $$sig_specs{SignatureIndex};
        foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, map { $$specs{"$_-$form-$qty_index"} ? "$_-$form-$qty_index" : () } ( 'chkOverrideEquipment', 'chkOverrideStockCutEquipment', 'chkOverrideCalculatedCuts' );
        } # end foreach
    } # end foreach

    return @v;

} # end sub has_overrides

sub signature_needs {
	my ( $Project, $sig_specs ) = @_;

	if ( $Project->Type()->name() eq 'Envelopes' ) {
        $openprint::log->debug(" ** Project Type is Envelopes, Cutting Service is NOT needed ** ") if DEBUG;
		return 0;
	} # end if 

	my $services = $Project->services();
    if ( $$services{NoBindery} ) {
        $openprint::log->debug(" ** Project is marked as No bindery, Cutting not needed ! ** ") if DEBUG;
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
					 $$sig_specs{'hdnSuppliedStockWidth'.$qty_index} == $$sig_specs{txtWidth} 
					 and $$sig_specs{'hdnSuppliedStockHeight'.$qty_index} == $$sig_specs{txtHeight}
					) or (
						$$sig_specs{'hdnSuppliedStockWidth'.$qty_index} == $$sig_specs{txtHeight}
						and $$sig_specs{'hdnSuppliedStockHeight'.$qty_index} == $$sig_specs{txtWidth}
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
	my ( $Project ) = @_;

	my $services = $Project->services();

	if ( $$services{NoBindery} ) {
        $openprint::log->debug(" ** Project is marked as No bindery, Cutting not needed ! ** ") if DEBUG;
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
	$openprint::log->debug("CUTTING NOT NEEDED!") if DEBUG;
	return 0;
} # end sub neccessary

sub load_equipment {
    my ( $Project ) = @_;
    my $services = $Project->services();

	my @capabilities = ('Y','When Printing','When Folding');
	if ( $$services{SaddleStitching} or $$services{LoopStitching} ) {
		push @capabilities, 'When Stitching';
	} # end if
	if ( sets::isin( $Project->Type()->name(), ['Banners','InkjetOutputs'] ) ) {
		push @capabilities, 'Large Format';
	} # end if
if ( 0 ) {
	my @capabilities = ('Y');
	if ( sets::isin( $Project->Type()->name(), ['Banners','InkjetOutputs'] ) ) {
		push @capabilities, 'Large Format';
	} # end if
}
	$log->debug("load_equipment");
	@equipment = openprint::Equipment->find( Specifications => {'Cutting Capable'=>\@capabilities}, useinestimating=>1, order=>'lower(strName)');
	@PreFoldingEquipment = openprint::Equipment->find( Specifications => {'Cutting Capable'=>['Y','When Printing']}, 'useinestimating'=>1,'order'=>'lower(strName)');
} # end sub load_equipment

sub signature_calc_stock_cutting {
	my ( $Project, $specs, $qty_index, $Stocks ) = @_;

	my %results = (
			Status	=> 'calculated',
			);

	my @my_equipment;
	if ( (defined $$specs{"chkOverrideStockCutEquipment-$qty_index"}) and ( $$specs{"chkOverrideStockCutEquipment-$qty_index"} eq 'Y' ) ) {
		$openprint::log->debug("Overriding Equipment! " . $$specs{"ddmStockCutEquipment-$qty_index"}) if DEBUG;
		@my_equipment = ( new openprint::Equipment( $$specs{"ddmStockCutEquipment-$qty_index"} ) );
    } else {
		load_equipment( $Project ) if ! @equipment;
        @my_equipment = @equipment;
	} # end if

	if ( ! @my_equipment ) {
		$results{alert} = 'We have no cutting equipment.<br/>';
		$results{Status} = 'uncalculated';
		return %results;
	} # end if

	my $services = $Project->services();

	my $Cutting = openprint::Service->find_one(name=>'Cutting');
	my $CuttingMakeReady = openprint::Service->find_one(name=>'CuttingMakeReady');
	my $BladeCleaning = openprint::Service->find_one(name=>'Blade Cleaning');

	my $total = 0;
	my $total_mprice = 0;

	foreach my $Stock_Amount ( @{$Stocks} ) {
		my $Paper = $$Stock_Amount{Stock};
		my $paper_string = $Paper->id_string();
		if ( ! $Paper ) {
			$results{alert} .= "Stock object not found for " . $paper_string.'<br/>';
			$openprint::log->error("Stock object not found for " . $paper_string );
			next;
		} # end if
# Add cutting the sheet prior to printing
		if ( ! ( $Paper->width() and $Paper->height() ) ) {
			$results{alert} .= "Paper does not have width and height for " . $paper_string.'<br/>';
			$openprint::log->error("Paper does not have width and height for " . $paper_string );
			next;
		} # end if
		if ( ($Paper->width() == $Paper->start_width()) and ($Paper->height() == $Paper->start_height() ) ) {
			$results{alert} .= "Paper does not need cutting " . $paper_string.'<br/>';
			$openprint::log->error("Paper does not need cutting for " . $paper_string );
			next;
		} # end if
		my $calliper = $Paper->calliper();
		if ( ! $calliper ) {
			$results{alert} .= "Calliper is unknown for Stock . " . $Paper->to_string().'<br/>';
		} # end if

		my ( $start_width, $start_height, $width, $height );

		if ( ($Paper->start_width() >= $Paper->width()) and ($Paper->start_height() >= $Paper->height()) ) {
			( $start_width, $start_height, $width, $height ) = 
				( 
				 ( $Paper->start_width() ? $Paper->start_width() : $Paper->width() ),
				 ( $Paper->start_height() ? $Paper->start_height() : $Paper->height() ), 
				 $Paper->width(), 
				 $Paper->height()
				);
		} else {
			( $start_width, $start_height, $width, $height ) = 
				( 
				 ( $Paper->start_width() ? $Paper->start_width() : $Paper->height() ),
				 ( $Paper->start_height() ? $Paper->start_height() : $Paper->width() ), 
				 $Paper->height(), 
				 $Paper->width()
				);
		} # end if

		$results{Breakdown} .= sprintf('<b>Cutting prior to printing: %s</b><br/>', $Paper->to_string() );

		my $mprice = 0;
		my $bestPrice = undef;
		my $bestEquipment;

	# Has to happen on normal cutters
		foreach my $Equipment ( @my_equipment ) {
			my $capable = $Equipment->specification( 'Cutting Capable' );
			
			if ( $capable ne 'Y' and $capable ne 'Large Format' ) {
				$results{Breakdown} .= 'Equipment ' . $Equipment->name().': Not capable for stock cutting.' if @my_equipment == 1;
				next;
			} 
			$results{Breakdown} .= 'Equipment: '.$Equipment->name().':';

			my $reason = $Equipment->fits( $start_width, $start_height );
			if ( $reason ) {
				$results{Breakdown} .= $reason . '<br/>';
				next;
			} # end if
			$results{Breakdown} .= '<br/>';

			my $liftDepth = $Equipment->specification( 'Maximum Lift Depth', $Paper->calliper() );
			# no lift depth means 1 at a time.

			my $width_cuts = int( $start_width / $width );
			my $height_cuts = int( $start_height / $height );
			my $sheets = $$Stock_Amount{quantity};
			$sheets = int( $sheets / ($width_cuts * $height_cuts) ) if $width_cuts and $height_cuts;
			# This accounts for cutting a sheet out of another, but not in half...
if ( 0 ) {
			if ( $width_cuts == 1 and $start_width != $width ) {
				$width_cuts += 1;
			} # end if
			if ( $height_cuts == 1 and $start_height != $height ) {
				$height_cuts += 1;
			} # end if
}

			my $price = 0;
			if ( $CuttingMakeReady ) {
				my %setupCost = $CuttingMakeReady->get_price( undef, $Equipment );
				$results{Breakdown} .= sprintf('MakeReady: %.2f<br/>', $setupCost{price} );
				$price += $setupCost{price};
			} # end if MakeReady
			my $service_price = 0;
			if ( $Cutting ) {
				my %ServicePrice = $Cutting->get_price( $sheets, $Equipment );
				foreach my $cuts ( $width_cuts-1, $height_cuts-1 ) {
					next if ! $cuts;
		$openprint::log->warn("Negative CUTS!") if $cuts < 1;
					my $runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : $sheets;
					my $cut_price = ( $runs * $cuts * $ServicePrice{price} );
					$service_price += $cut_price;
					$results{Breakdown} .= sprintf('Cutting %d sheets into %d sheets in %d runs: %.2f<br/>', $sheets, $sheets*($cuts+1), $runs, $cut_price );
					$sheets *= $cuts+1;
				} # end foreach
				$price += $service_price;
			} # end if Cutting
			my %cleaning;
			if ( $Paper->bladecleaning() and $BladeCleaning ) {
				%cleaning = $BladeCleaning->get_price( undef, $Equipment );
				$results{Breakdown} .= sprintf('Blade Cleaning: %.2f<br/>', $cleaning{price} );
				$price += $cleaning{price};
			} # end if
			if ( ( ! defined $bestPrice ) or ( $bestPrice > $price ) ) {
				$mprice = $service_price + ( defined $cleaning{price} ? $cleaning{price} : 0 );
				$bestPrice = $price;
				$bestEquipment = $Equipment;
			} # end if
		} # end for each equipment
		if ( ! $bestEquipment ) {
			$results{alert} .= "No equipment found for cutting stock $paper_string<br/>";
		} # end if
		$total += $bestPrice;
		$total_mprice += $mprice;
	} # end foreach Paper
	$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};	
	$results{Price} 		= Math::Round::nearest( 0.01, $total );
	$results{MPrice}		= Math::Round::nearest( 0.01,($total_mprice/$$specs{'txtQuantity'.$qty_index})*1000 );

	$results{Status} = 'uncalculated' if $results{alert};

	return %results;
} # end sub signature_calc_stock_cutting

sub signature_calc_folding_cutting {
	my ( $Project, $sig_specs, $specs, $qty_index, $Paper, $I, $fold_specs, $calc_hash ) = @_;

	my %results = (
			Status	=> 'calculated',
			);

	my $services = $Project->services();
	return %results if ! ( $$services{Folding} and @{$$services{Folding}} );
	return %results if ! $$specs{'txtQuantity'.$qty_index};

#$openprint::log->debug("Loading Paper from signature in signature_calc_folding_cutting");
	$results{Status} = 'uncalculated';
	my $form = $$sig_specs{SignatureIndex};

	# Consider Cutting before folding, compare pages on signature verses folds, for example 24->16+8
	$fold_specs = openprint::service::get_specs_ref( $Project, $$services{Folding}[0] ) if ! $fold_specs;
	my %folds;
	foreach my $fold_index ( 1 .. 4 ) {
		if ( $$fold_specs{"FoldQty-$form-$qty_index-$fold_index"} ) {
			$folds{$$fold_specs{"FoldType-$form-$qty_index-$fold_index"}} = $$fold_specs{"FoldQty-$form-$qty_index-$fold_index"};
		} # end if
	} # end foreach fold
	my $folding_cuts = misc::sum( map { $folds{$_} } keys %folds);
	$results{Breakdown} .= sprintf('<b>Cutting prior to folding sig: %d qty: %d: %dpg -> folds %s</b><br/>', $form, $qty_index, $I->pages(), join(',',keys %folds ) );
	if ( $folding_cuts <= 1 ) {
		$results{Breakdown} .= sprintf('Not needed<br/>' );
		$results{Status} = 'calculated';
		return %results;
	} # end if


# Grab the Calliper
	if ( $$specs{"chkOverrideCalliper-$form"} ne 'Y' ) {
		$$specs{"txtStockCalliper-$form"} = $Paper->calliper();
	} # end if

	my @my_equipment;

	if ( $$specs{"chkOverrideFoldCutEquipment-$form-$qty_index"} eq 'Y' ) {
		$log->debug("Overriding Equipment! " . $$specs{"ddmFoldCutEquipment-$form-$qty_index"}) if DEBUG;
		@my_equipment = ( new openprint::Equipment( @$specs{"ddmFoldCutEquipment-$form-$qty_index"} ) );
    #} elsif ( $$calc_hash{'Cutting::signature_calc_folding_cutting::equipment'} ) {
        #@my_equipment = @{$$calc_hash{'Cutting::signature_calc_folding_cutting::equipment'}};
	} else {
		load_equipment( $Project ) if ! @equipment;
		@my_equipment = @equipment;
#openprint::Equipment->find( 'Specifications' => {'Cutting Capable'=>'Y'}, 'useinestimating'=>1,'order'=>'lower(strName)');
		#@{$$calc_hash{'Cutting::signature_calc_folding_cutting::equipment'}} = @my_equipment;
	} # end if

	if ( ! @my_equipment ) {
		$results{alert} = 'We have no cutting equipment.<br/>';
		$results{Status} = 'uncalculated';
		return %results;
	} # end if
	my $bestPrice = undef;
	my $bestEquipment;
# Has to happen on normal cutters
	foreach my $Equipment ( @my_equipment ) {
		my $capable = $Equipment->specification( 'Cutting Capable' );
		if ( $capable ne 'Y' and $capable ne 'Large Format' ) {
			$results{Breakdown} .= 'Not capable for stock cutting.';
			next;
		} 
		next if $Equipment->specification('Type') eq 'Stitcher';
		if ( $$services{NoOfflineBindery} and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$results{Breakdown} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
			next;
		} # end if

		$results{Breakdown} .= "\tEquipment: ".$Equipment->name().':';

		my $reason = $Equipment->fits( $Paper->width(), $Paper->height() );
		$results{Breakdown} .= $reason . '<br/>';
		next if $reason;

		my $liftDepth = $Equipment->specification( 'Maximum Lift Depth', $Paper->calliper() );
		next if ! $liftDepth;

		my $sheets = ceil( $$sig_specs{'txtQuantity'.$qty_index} / $I->imposition() );
		my %ServicePrice = openprint::service::get_price_object( 'Cutting', $sheets, $Equipment );
		my $price = 0;
		my $runs = ceil( $sheets*$Paper->calliper()/$liftDepth );
		$price += ( $runs * $folding_cuts * $ServicePrice{Price} );
		$results{Breakdown} .= sprintf('Cutting %d sheets in %d runs: %.2f<br/>', $sheets, $runs, $price );
		my $setupCost = openprint::service::get_price( 'CuttingMakeReady', undef, $Equipment );
		$results{Breakdown} .= sprintf('MakeReady: %.2f<br/>', $setupCost );
		my $totalPrice = $setupCost + $price;
		if ( $Paper->bladecleaning() ) {
			my %cleaning = openprint::service::get_price_object( 'Blade Cleaning', undef, $Equipment );
			$results{Breakdown} .= sprintf('Blade Cleaning: %.2f<br/>', $cleaning{price} );
			$totalPrice += $cleaning{price};
		} # end if
		if ( ( ! defined $bestPrice ) or ( $bestPrice > $totalPrice ) ) {
			$bestPrice = $totalPrice;
			$bestEquipment = $Equipment;
		} # end if
	} # end for each equipment
	$results{Breakdown} .= sprintf('Total: $%.2f<br/>', $bestPrice );
	$results{Status}		= $bestEquipment ? 'calculated' : 'uncalculated';
	$results{Price}		= sprintf($config{ProjectMoneyFormat}, $bestPrice );
	$results{MPrice}		= ($bestPrice/$$specs{'txtQuantity'.$qty_index})*1000;
	$results{Equipment}	= $bestEquipment;
	return %results;
} # end sub signature_calc_folding_cutting

sub signature_calc {
	my ( $Project, $sig_specs, $specs, $qty_index, $Paper, $Imposition, $folding_specs, $calc_hash ) = @_;

	if ( ! $Paper->cuttable() ) {
		$$specs{alert} = $Paper->to_string() . ': Stock is not cuttable.';
		$$specs{Status} = 'calculated';
		return;
	} # end if

	my %results = (
			Status	=> 'calculated',
			Breakdown	=>	'<b>Post press:</b><br/>',
			);
	my $services = $Project->services();
	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] ) if $$services{''} and @{$$services{''}};

	my $form = $$sig_specs{SignatureIndex};

	my @my_equipment;
	if ( (defined $$specs{"chkOverrideEquipment-$form-$qty_index"} ) and ( $$specs{"chkOverrideEquipment-$form-$qty_index"} eq 'Y' ) ) {
		@my_equipment = ( new openprint::Equipment( $$specs{"ddmEquipment-$form-$qty_index"} ) );
	} else {
		load_equipment( $Project ) if ! @equipment;
		@my_equipment = @equipment;
	} # end if

	if ( ! @my_equipment ) {
		$results{alert} = 'We have no cutting equipment.<br/>';
		$results{Status} = 'uncalculated';
		return %results;
	} # end if

	$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};	
	if ( ! $$specs{"txtQuantity$qty_index"} ) {
		$results{alert} = 'No quantity entered.<br/>';
		$results{Status} = 'uncalculated';
		return %results;
	} # end if

# Grab the Calliper

	my $calliper = $Paper->calliper();
	if ( ! $calliper ) {
		$openprint::log->debug("**** NO Calliper ****") if DEBUG;
		$results{alert} .= "Calliper is unknown for signature $form.<br/>";
		$results{Status} = 'uncalculated';
		return %results;
	} # end if

	my $stitching_imposition;
	my $stitching_specs;

	if ( $$services{SaddleStitching} ) {
		$stitching_specs = openprint::service::get_specs_ref( $Project, $$services{SaddleStitching}[0] );
		$stitching_imposition = $$stitching_specs{'Imposition'.$qty_index};
	} elsif ( $$services{LoopStitching} ) {
		$stitching_specs = openprint::service::get_specs_ref( $Project, $$services{LoopStitching}[0] );
		$stitching_imposition = $$stitching_specs{'Imposition'.$qty_index};
	} elsif ( $$services{PerfectBound} ) {
		$stitching_specs = openprint::service::get_specs_ref( $Project, $$services{PerfectBound}[0] );
		$stitching_imposition = $$stitching_specs{'Imposition'.$qty_index};
	} elsif ( $$services{CornerStitching} ) {
		$stitching_specs = openprint::service::get_specs_ref( $Project, $$services{CornerStitching}[0] );
		$stitching_imposition = $$stitching_specs{'Imposition'.$qty_index};
	} # end if
	my %pretrim_sides;
	my $Stitcher;
	if ( $stitching_specs and $$stitching_specs{"ddmEquipment$qty_index"} ) {
		$Stitcher = new openprint::Equipment( $$stitching_specs{"ddmEquipment$qty_index"} );
		my $pretrim_sides = $Stitcher->specification('Pre-trimmed Edges '.$$sig_specs{txtSignatureType});
		$pretrim_sides = $Stitcher->specification('Pre-trimmed Edges') if ! $pretrim_sides;
		%pretrim_sides = map { $_, $_ } split(',',$pretrim_sides) if $pretrim_sides;
		$stitching_imposition = 1 if ! defined $stitching_imposition;
	}
	
	my $has_uv = $$services{UVCoating} and openprint::Estimating::UVCoating::signature_needs( $Project, $sig_specs );

	my @folding_impositions;

	my $Folder;
	if ( $$services{Folding} and @{$$services{Folding}} ) {
		$folding_specs = openprint::service::get_specs_ref( $Project, $$services{Folding}[0] ) if ! $folding_specs;
		$Folder = new openprint::Equipment( $$folding_specs{"ddmEquipment-$form-$qty_index"} ) if $$folding_specs{"ddmEquipment-$form-$qty_index"};
		$Folder = undef if $Folder and ! $Folder->id();
		if ( $$Imposition{Folds} ) {
			@folding_impositions = @{$$Imposition{Folds}};
		} else {
			foreach my $fold_index ( 1 .. 4 ) {
				next if ! $$folding_specs{"FoldQty-$form-$qty_index-$fold_index"};
				next if ! $$folding_specs{"FoldType-$form-$qty_index-$fold_index"};
				my $folding_imposition = new openprint::Imposition();
				$folding_imposition->Paper( $Paper );
				$folding_imposition->columns( $$folding_specs{"FoldColumns-$form-$qty_index-$fold_index"} );
				$folding_imposition->rows( $$folding_specs{"FoldRows-$form-$qty_index-$fold_index"} );
				$folding_imposition->quantity( $$folding_specs{"FoldQty-$form-$qty_index-$fold_index"} );
				push @folding_impositions, $folding_imposition;
				$folding_imposition->display('Fold ' . $$folding_specs{"FoldType-$form-$qty_index-$fold_index"} ) if DEBUG;
			} # end if
		} # end foreach fold_index
	} # end if

#$openprint::log->debug("Folding impos " . @folding_impositions  . ' eq ' . @my_equipment );

	if ( $$Imposition{image_orientation} eq 'Horizontal' ) {
		$stitching_imposition = $$Imposition{columns} if $stitching_imposition > $$Imposition{columns};
	} else {
		$stitching_imposition = $$Imposition{rows} if $stitching_imposition > $$Imposition{rows};
	} # end if

	my $Press = $Imposition->Press();
	my $output_format = $Press->specification('OutputFormat');
	
	my $Cutting = openprint::Service->find_one(name=>'Cutting');
	my $CuttingMakeReady = openprint::Service->find_one(name=>'CuttingMakeReady');
	my $BladeCleaning = openprint::Service->find_one(name=>'Blade Cleaning');

	my $I = $Imposition->copy();
	my $trim_before_folding = 0;

		# Take care of cutting before folding
	if ( @folding_impositions ) {

$openprint::log->debug("Folding impositions: " . @folding_impositions ) if DEBUG;

		my $folding_cuts = 0;
		if ( ( defined $$specs{"OverrideFoldingCuts-$form-$qty_index"} ) and ( $$specs{"OverrideFoldingCuts-$form-$qty_index"} eq 'Y' ) ) {
			$folding_cuts = $$specs{"FoldingCuts-$form-$qty_index"};
		} else {
			if ( ( @folding_impositions == 1 ) and ( $folding_impositions[0]->imposition() == 1 ) and ( ! $stitching_imposition ) and ( $folding_impositions[0]->quantity() == 1 ) and ( (!$Folder) or ( $Folder->id() != $Press->id() ) ) ) {
				$trim_before_folding = 1;
			} else {
				$openprint::log->debug("Folds: " .@folding_impositions ) if DEBUG;
				foreach my $folding_imposition ( @folding_impositions ) {
					$folding_cuts += $$folding_imposition{quantity}-1 if $$folding_imposition{quantity};
				} # end foreach
				$folding_cuts += @folding_impositions - 1;
			} # end if
		} # end if

		if ( $folding_cuts ) {
			load_equipment( $Project ) if ! @PreFoldingEquipment;
			my @PreFoldEquipment = @PreFoldingEquipment;
			if ( ( defined $$specs{"OverrideFoldingEquipment-$form-$qty_index"} ) and ( $$specs{"OverrideFoldingEquipment-$form-$qty_index"} eq 'Y' ) ) {
				if ( ! sets::isin( $$specs{"OverrideFoldingEquipment-$form-$qty_index"}, [ map { $_->id() } @PreFoldingEquipment ] ) ) {
					$results{alert} .= 'Overriden Equipment is not suitable for cutting before folding.<br/>';
				} # end if
				@PreFoldEquipment = ( new openprint::Equipment( $$specs{"FoldingEquipment-$form-$qty_index"} ) );
			} # end if
			foreach my $Equipment ( @PreFoldEquipment ) {
				my $liftDepth = $Equipment->specification( 'Maximum Lift Depth', $calliper );
				my $sheets = ceil( $$sig_specs{'txtQuantity'.$qty_index} / $$I{imposition} );
				$sheets *= $$sig_specs{PageQuantity} if $$sig_specs{PageQuantity};
				my $runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : $sheets;
				$results{Breakdown} .= '# of pre-folding cuts: ' . $folding_cuts . ' => ' .($folding_cuts * $sheets) . '<br/>';
				my %ServicePrice = $Cutting->get_price( undef, $Equipment );
				if ( $ServicePrice{units} eq 'per cut' ) {
					%ServicePrice = $Cutting->get_price( $sheets * $folding_cuts, $Equipment );
				} else {
					%ServicePrice = $Cutting->get_price( $sheets, $Equipment );
				} # end if
				my $price;
				if ( $ServicePrice{units} eq 'per inch' ) {
					$price = ( $runs * $folding_cuts * $ServicePrice{price} * $I->image_height() );
					$results{Breakdown} .= sprintf('%d pre-folding cuts on %d sheets in %d runs * %.2f inches: %.2f%s=%.2f<br/>', $folding_cuts, $sheets, $runs, $I->image_height(), @ServicePrice{'price','units'}, $price );
				} else {
					$price = ( $runs * $folding_cuts * $ServicePrice{price} );
					$results{Breakdown} .= sprintf('%d pre-folding cuts on %d sheets in %d runs: %.2f%s=%.2f<br/>', $folding_cuts, $sheets, $runs, @ServicePrice{'price','units'}, $price );
				} # end if
				if ( ( ! defined $results{FoldingPrice} ) or ( $price < $results{FoldingPrice} ) ) {
					$results{FoldingPrice} = $price;
					$results{FoldingEquipment} = $Equipment;
				} # end if
			} # end foreach Equipmenet
		} else {
			$results{Breakdown} .= 'No pre-folding cuts:<br/>';
		} # end if folding_cuts
		$results{FoldingCuts} = $folding_cuts;
	} # end if @folding

	#The Paper might be a roll, and the output of printing might still be a roll.
	my $bestPrice = undef;
	my $bestM = 0;
	my $bestEquipment;
	foreach my $Equipment ( @my_equipment ) {
		next if ! $Equipment->id();
		$results{Breakdown} .= 'Equipment ' . $Equipment->name() .':';
		if ( $$services{NoOfflineBindery} and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$results{Breakdown} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
			next;
		} # end if
		my $cutting_capable = $Equipment->specification('Cutting Capable');

		if ( $cutting_capable eq 'When Folding' ) {
			if ( ! $folding_specs ) {
				$results{Breakdown} .= 'Not folding<br/>';
				next;
			} # end if
			if ( $trim_before_folding ) {
				$results{Breakdown} .= 'is 1out, so trim before folding.<br/>';
				next;
			} # end 

			if ( ! $$folding_specs{"ddmEquipment-$form-$qty_index"} ) {
				$results{Breakdown} .= 'Unknown folding equipment<br/>';
				next;
			} elsif( $$folding_specs{"ddmEquipment-$form-$qty_index"} ne $Equipment->id() ) {
				my $Folder = new openprint::Equipment( $$folding_specs{"ddmEquipment-$form-$qty_index"} );
				$results{Breakdown} .= 'Not folding on ' . $Equipment->strid(). ' Folder is ' . $Folder->strid() . '<br/>';
				next;
			} # end if
		} elsif ( ( $cutting_capable eq 'When Printing' ) and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$results{Breakdown} .= 'Not printing on ' . $Equipment->strid() . '<br/>';
			next;
		} elsif ( $cutting_capable eq 'When Stitching' ) {
			if ( $$stitching_specs{'ddmEquipment'.$qty_index} != $Equipment->id() ) {
				$results{Breakdown} .= 'Not stitching on ' . $Equipment->strid() . '<br/>';
				next;
			} # end if
			if ( keys %pretrim_sides ) {
				$results{Breakdown} .= 'Needs pre-trim before Stitching, cant use Stitcher for cutting<br/>';
				next;
			} # end if
		} # end if

		my $sheets = ceil( $$sig_specs{'txtQuantity'.$qty_index} / $$I{imposition} );
		$sheets *= $$sig_specs{PageQuantity} if $$sig_specs{PageQuantity};
		if ( my $Spec = $Equipment->Specification('Cutting Overs') ) {
			if ( $$Spec{units} eq 'Sheets' ) {
				$sheets += $$Spec{value};
			} # end if
		} # end if

		my ( $sheet_width, $sheet_height ) = ( $Paper->width(), $Paper->height() );
		if ( $output_format and ( $output_format eq 'Roll' ) ) {
			if ( ( $_ = $Equipment->specification('Maximum Sheet Width') ) and ( $sheet_width > $_ ) ) {
				$results{Breakdown} .= 'Doesnt fit.<br/>';
				next;
			} # end if
			# Adjust imposition to account for cutting to maximum size
			$sheet_height = $Equipment->specification('Maximum Sheet Length');
			if ( ! $sheet_height ) {
				$I->rows( $sheets );
				$I->dutch_rows( $sheets ) if $I->dutch_rows();
				$sheet_height = $I->layout_height();
				$sheets = 1;
			} else {
				$I->rows( $I->rows() * int($sheet_height / $I->layout_height()) );
				$I->dutch_rows( $I->dutch_rows() * int($sheet_height / $I->layout_height()) ) if $I->dutch_rows();
				$sheets = ceil( $sheets / $I->rows() );
			} # end if
			$results{Breakdown} .= $I->to_string() . '<br/>';
		} elsif ( my $reason = $Equipment->fits( $sheet_width, $sheet_height ) ) {
			$results{Breakdown} .= $reason . '<br/>';
			next;
		} # end if
		$results{Breakdown} .= '<br/>';
				
		my $liftDepth = $Equipment->specification( 'Maximum Lift Depth with UVCoating' ) if $has_uv;
		$liftDepth = $Equipment->specification( 'Maximum Lift Depth', $calliper ) if ! $liftDepth;
		$liftDepth = 0 if ! defined $liftDepth;
		$results{Breakdown} .= "(Lift: $liftDepth)<br/>";
# calculate cuts
		my $vertical_cuts = 0;
		my $horizontal_cuts = 0;
		my $dutch_vertical_cuts = 0;
		my $dutch_horizontal_cuts = 0;

		if ( (defined $$specs{'chkOverrideCalculatedCuts-'.$form.'-'.$qty_index}) and ( $$specs{'chkOverrideCalculatedCuts-'.$form.'-'.$qty_index} eq 'Y' ) ) {
			$vertical_cuts = $$specs{"txtVerticalCuts-$form-$qty_index"};
			$horizontal_cuts = $$specs{"txtHorizontalCuts-$form-$qty_index"};
			$dutch_vertical_cuts = $$specs{"txtDVerticalCuts-$form-$qty_index"};
			$dutch_horizontal_cuts = $$specs{"txtDHorizontalCuts-$form-$qty_index"};
		} else {
# Regular book signatures will be trimmed by the stitcher, so we only need 1 cut per imposition
# Most stitchers do 3knife trim, but some do not. Most need a Head Trim, some need Head & Foot
# interior vertical cuts = $sig_specs{hdnImpositionColumns}-1
			if ( $$sig_specs{txtSignatureType} ) {

	# but if we are cutting into smaller signatures, then we need more cutting
	#$openprint::log->debug("Sitching $stitching_imposition out printing $$sig_specs{'txtImposition'.$qty_index}out");
	#$openprint::log->debug("have signaturetype $$sig_specs{txtSignatureType} ");
				if ( $I->pages() and ( ( ! $folding_specs ) or ( ! ( $Folder and $Folder->specification('Cutting Capable') ) ) ) ) {
#$openprint::log->debug("Cutting because not folding or can't cut on folder $folding_specs $$Folder{strid} " . $Folder->specification('Cutting Capable') );
	# Have to cut the pages out
					$vertical_cuts += int ( ($I->page_columns()-1)*$I->columns()*2 ) + 2;
					$horizontal_cuts += int( ($I->page_rows()-1)*$I->rows() * 2 ) + 2;
			
				} elsif ( $stitching_imposition and ! @folding_impositions ) {
					$vertical_cuts += int ($$I{columns} / $stitching_imposition)-1;
					$horizontal_cuts += int ($$I{rows} / $stitching_imposition)-1; 
				} elsif ( $$printing_specs{rdbTemplateType} eq 'PlasticCoil' ) {
					# This is special... something about if it's plasticCoil... you have to cut it into 8's...

					if ( $I->pages() > 8 ) {
						if ( @folding_impositions == 1 and $folding_impositions[0]->quantity() <= 1 and $folding_impositions[0]->imposition() == 1 ) {
							# According to Brendan, will trim it first.
							$vertical_cuts += 2;
							$horizontal_cuts += 2;
						} else {
							# Going to fold it first.
							foreach my $folding_imposition ( @folding_impositions ) {
								my $columns =  $$folding_imposition{columns} ? $$I{columns} / $$folding_imposition{columns} : $$I{columns};
								$vertical_cuts += 1+$columns;# = 2+$$I{columns}-1
								my $rows = $$folding_imposition{rows} ?$$folding_imposition{rows} : $$I{rows};
								$horizontal_cuts += 1 + $rows;#2 + $$I{rows}-1
								if ( $$sig_specs{'ddmBleedSize'.$qty_index} and ( 
											( $$I{image_orientation} eq 'Horizontal' and ( $$sig_specs{BleedLeft} or $$sig_specs{BleedRight} ) ) or
											( $$I{image_orientation} eq 'Vertical' and ( $$sig_specs{BleedTop} or $$sig_specs{BleedBottom} ) ) )
								   ) {
									$horizontal_cuts += $rows-1;
								} # end if
								if ( 
										( $$I{image_orientation} eq 'Vertical' and ( $$sig_specs{BleedLeft} or $$sig_specs{BleedRight} ) ) or
										( $$I{image_orientation} eq 'Horizontal' and ( $$sig_specs{BleedTop} or $$sig_specs{BleedBottom} ) )
								   ) {
									$vertical_cuts += $columns-1;
								} # end if
							} # end foreach
						} # end if
					} else {
						$vertical_cuts += int ( ($I->page_columns()-1)* (($I->columns()-1)*2) ) + 2;
					} # end if
				} else {
					$vertical_cuts += $$I{columns}-1;
					$horizontal_cuts += $$I{rows}-1;
				} # end if
				foreach my $side ( keys %pretrim_sides ) {
					# What I am thinking here, is that if it was 2 out, the in between head trim would already have been done, so there is just 1 to do
					if ( $$I{image_orientation} eq 'Vertical' ) {
						$horizontal_cuts += 1;
					} else {
						$vertical_cuts += 1;
					} # end if
				} # end foreach pre-trimmed sides
			} elsif ( @folding_impositions >= 1 and $folding_impositions[0]->imposition() > 1 and ( $Folder and $Folder->specification('Cutting Capable') ) ) {
	# Splitting the folded products is done on the folder for free
	#if ( ( $$folding_imposition{columns} > 1 ) and ( $$folding_imposition{columns} < $$I{columns} ) ) {
	#$vertical_cuts += ($$I{columns} / $$folding_imposition{columns})-1;
	#} # end if
			} else {
$openprint::log->debug("Not a book") if DEBUG;
				my $columns =  $$I{columns};
				$vertical_cuts += 1+$columns;# = 2+$$I{columns}-1
				if (
						( $$I{image_orientation} eq 'Vertical' and ( $$sig_specs{BleedLeft} or $$sig_specs{BleedRight} ) ) or
						( $$I{image_orientation} eq 'Horizontal' and ( $$sig_specs{BleedTop} or $$sig_specs{BleedBottom} ) )
				   ) {
					$vertical_cuts += $columns-1;
				} # end if
				my $rows = $$I{rows};
				$horizontal_cuts += 1 + $rows;#2 + $$I{rows}-1
				if ( $$sig_specs{'ddmBleedSize'.$qty_index} and ( 
							( $$I{image_orientation} eq 'Horizontal' and ( $$sig_specs{BleedLeft} or $$sig_specs{BleedRight} ) ) or
							( $$I{image_orientation} eq 'Vertical' and ( $$sig_specs{BleedTop} or $$sig_specs{BleedBottom} ) ) )
				   ) {
					$horizontal_cuts += $rows-1;
				} # end if
			} # end if

	# Dutch cuts don't happen on books
			if ( ( ! $$sig_specs{txtSignatureType} ) and ! @folding_impositions ) {
	# Now consider Dutch cuts
				if ( $$I{dutch_columns} and $$I{dutch_rows} ) {
					$dutch_vertical_cuts += 1 + $$I{dutch_columns};
					$dutch_horizontal_cuts += $$I{dutch_rows}; # +1 - 1
						if ( ( $$sig_specs{BleedTop} and $$sig_specs{BleedBottom} ) or ($$sig_specs{BleedLeft} and $$sig_specs{BleedRight} ) ) {
							$dutch_horizontal_cuts += 1;
						} # end if
					if ( 
							( $$I{image_orientation} eq 'Vertical' and ( $$sig_specs{BleedTop} or $$sig_specs{BleedBottom} ) ) or
							( $$I{image_orientation} eq 'Horizontal' and ( $$sig_specs{BleedLeft} or $$sig_specs{BleedRight} ) )
					   ) {
						$dutch_vertical_cuts += $$I{dutch_columns}-1;
					} # end if
					if ( 
							( $$I{image_orientation} eq 'Horizontal' and ( $$sig_specs{BleedTop} or $$sig_specs{BleedBottom} ) ) or
							( $$I{image_orientation} eq 'Vertical' and ( $$sig_specs{BleedLeft} or $$sig_specs{BleedRight} ) )
					   ) {
						$dutch_horizontal_cuts += $$I{dutch_rows}-1;
					} # end if
				} # end if dutch imposition
			} # end if exists signaturetype

			$$specs{"txtVerticalCuts-$form-$qty_index"} = $vertical_cuts;
			$$specs{"txtHorizontalCuts-$form-$qty_index"} = $horizontal_cuts;
			$$specs{"txtDVerticalCuts-$form-$qty_index"} = $dutch_vertical_cuts;
			$$specs{"txtDHorizontalCuts-$form-$qty_index"} = $dutch_horizontal_cuts;
		}
		$$specs{"txtCalculatedCuts-$form-$qty_index"} = $vertical_cuts + $horizontal_cuts + $dutch_vertical_cuts + $dutch_horizontal_cuts;

		my $cuts = $$specs{"txtCalculatedCuts-$form-$qty_index"};

		my $totalPrice = 0;
		my $mprice = 0;
		my $price;

		my %ServicePrice = $Cutting->get_price( undef, $Equipment );
		if ( %ServicePrice ) {
			if ( $ServicePrice{units} eq 'per cut' ) {
				%ServicePrice = $Cutting->get_price( $sheets * $cuts, $Equipment );
			} else {
				%ServicePrice = $Cutting->get_price( $sheets, $Equipment );
			} # end if
		} # end if

		my $runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : $sheets;
		$results{Breakdown} .= '# of cuts: ' . $cuts . ' => ' .($cuts * $sheets) . '<br/>';

		if ( %ServicePrice ) {
			if ( $vertical_cuts > $horizontal_cuts ) {
				if ( $ServicePrice{units} eq 'per inch' ) {
					$price = ( $runs * $vertical_cuts *$ServicePrice{price} * $I->image_height() );
					$results{Breakdown} .= sprintf('%d Vertical cuts on %d sheets in %d runs * %.2f inches: %.2f%s=%.2f<br/>', $vertical_cuts, $sheets, $runs, $I->image_height(), @ServicePrice{'price','units'}, $price );
				} else {
					$price = ( $runs * $vertical_cuts * $ServicePrice{price} );
					$results{Breakdown} .= sprintf('%d Vertical cuts on %d sheets in %d runs: %.2f%s=%.2f<br/>', $vertical_cuts, $sheets, $runs, @ServicePrice{'price','units'}, $price );
				} # end if
				$totalPrice += $price;
				if ( (!$config{'Dumb Cutting'}) or ( $config{'Dumb Cutting'} ne 'Y' ) ) {
					$sheets *= $$I{columns};
					$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : $sheets;
				} # end if
				if ( $ServicePrice{units} eq 'per inch' ) {
					$price = ( $runs * $horizontal_cuts *$ServicePrice{'price'} * $I->image_width() );
					$results{Breakdown} .= sprintf('%d Horizontal cuts on %d sheets in %d runs * %.2f inches: %.2f%s=%.2f<br/>', $horizontal_cuts, $sheets, $runs, $I->image_width(), @ServicePrice{'price','units'}, $price );
				} else {
					$price = ( $runs * $horizontal_cuts * $ServicePrice{price} );
					$results{Breakdown} .= sprintf('%d Horizontal cuts on %d sheets in %d runs: %.2f%s=%.2f<br/>', $horizontal_cuts, $sheets, $runs, @ServicePrice{'price','units'}, $price );
				} # end if
				$totalPrice += $price;
			} else {
				if ( $ServicePrice{units} eq 'per inch' ) {
					$price = ( $runs * $horizontal_cuts *$ServicePrice{price} * $I->image_width() );
					$results{Breakdown} .= sprintf('%d Horizontal cuts on %d sheets in %d runs * %.2f inches: %.2f%s=%.2f<br/>', $horizontal_cuts, $sheets, $runs, $I->image_width(), @ServicePrice{'price','units'}, $price );
				} else {
					$price = ( $runs * $horizontal_cuts * $ServicePrice{price} );
					$results{Breakdown} .= sprintf('%d Horizontal cuts on %d sheets in %d runs: %.2f%s=%.2f<br/>', $horizontal_cuts, $sheets, $runs, @ServicePrice{'price','units'}, $price );
				}
				$totalPrice += $price;
				if ( (!$config{'Dumb Cutting'}) or ( $config{'Dumb Cutting'} ne 'Y' ) ) {
					$sheets *= $$I{rows};
					$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : $sheets;
				} # end if
				if ( $ServicePrice{units} eq 'per inch' ) {
					$price = ( $runs * $vertical_cuts *$ServicePrice{price} * $I->image_height() );
					$results{Breakdown} .= sprintf('%d Vertical cuts on %d sheets in %d runs * %.2f inches: %.2f<br/>', $vertical_cuts, $sheets, $runs, $I->image_height(), $price );
				} else {
					$price = ( $runs * $vertical_cuts * $ServicePrice{price} );
					$results{Breakdown} .= sprintf('%d Vertical cuts on %d sheets in %d runs: %.2f<br/>', $vertical_cuts, $sheets, $runs, $price );
				}
				$totalPrice += $price;
			} # end if
		} # end if ServicePrice

		if ( $dutch_vertical_cuts or $dutch_horizontal_cuts ) {
			$results{Breakdown} .= "Dutch Cuts:<br/>";

			$sheets = ceil( $$sig_specs{'txtQuantity'.$qty_index} / $$I{imposition} );
			$sheets *= $$sig_specs{PageQuantity} if $$sig_specs{PageQuantity};
			$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : $sheets;

			if ( $dutch_vertical_cuts > $dutch_horizontal_cuts ) {
				if ( $ServicePrice{units} eq 'per inch' ) {
					$price = ( $runs * $dutch_vertical_cuts *$ServicePrice{price} * $I->image_width() );
					$results{Breakdown} .= sprintf('%d Vertical cuts on %d sheets in %d runs * %.2f inches: %.2f%s=%.2f<br/>', $dutch_vertical_cuts, $sheets, $runs, $I->image_width(), @ServicePrice{'price','units'}, $price );
				} else {
					$price = ( $runs * $dutch_vertical_cuts * $ServicePrice{price} );
					$results{Breakdown} .= sprintf('%d Vertical cuts on %d sheets in %d runs: %.2f%s=%.2f<br/>', $dutch_vertical_cuts, $sheets, $runs, @ServicePrice{'price','units'}, $price );
				} # end if
				$totalPrice += $price;
				if ( (!$config{'Dumb Cutting'}) or ( $config{'Dumb Cutting'} ne 'Y' ) ) {
					$sheets *= $$I{dutch_columns};
					$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : $sheets;
				} # end if
				if ( $ServicePrice{units} eq 'per inch' ) {
					$price = ( $runs * $dutch_horizontal_cuts *$ServicePrice{price} * $I->image_height() );
					$results{Breakdown} .= sprintf('%d Horizontal cuts on %d sheets in %d runs * %.2f inches: %.2f%s=%.2f<br/>', $dutch_horizontal_cuts, $sheets, $runs, $I->image_height(), @ServicePrice{'price','units'}, $price );
				} else {
					$price = ( $runs * $dutch_horizontal_cuts * $ServicePrice{price} );
					$results{Breakdown} .= sprintf('%d Horizontal cuts on %d sheets in %d runs: %.2f%s=%.2f<br/>', $dutch_horizontal_cuts, $sheets, $runs, @ServicePrice{'price','units'}, $price );
				} # end if
				$totalPrice += $price;
			} else {
				if ( $ServicePrice{units} eq 'per inch' ) {
					$price = ( $runs * $dutch_horizontal_cuts *$ServicePrice{price} * $I->image_height() );
					$results{Breakdown} .= sprintf('%d Horizontal cuts on %d sheets in %d runs * %.2f inches: %.2f%s=%.2f<br/>', $dutch_horizontal_cuts, $sheets, $runs, $I->image_height(), @ServicePrice{'price','units'}, $price );
				} else {
					$price = ( $runs * $dutch_horizontal_cuts * $ServicePrice{price} );
					$results{Breakdown} .= sprintf('%d Horizontal cuts on %d sheets in %d runs: %.2f<br/>', $dutch_horizontal_cuts, $sheets, $runs, $price );
				} # end if
				$totalPrice += $price;
				if ( (!$config{'Dumb Cutting'}) or ( $config{'Dumb Cutting'} ne 'Y' ) ) {
					$sheets *= $$I{dutch_rows};
					$runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : $sheets;
				} # end if
				if ( $ServicePrice{units} eq 'per inch' ) {
					$price = ( $runs * $dutch_vertical_cuts *$ServicePrice{price} * $I->image_width() );
					$results{Breakdown} .= sprintf("%d Vertical cuts on %d sheets in %d runs * %.2f inches: %.2f%s=%.2f<br/>", $dutch_vertical_cuts, $sheets, $runs, $I->image_width(), @ServicePrice{'price','units'}, $price );
				} else {
					$price = ( $runs * $dutch_vertical_cuts * $ServicePrice{price} );
					$results{Breakdown} .= sprintf('%d Vertical cuts on %d sheets in %d runs: %.2f%s=%.2f<br/>', $dutch_vertical_cuts, $sheets, $runs, @ServicePrice{'price','units'}, $price );
				} # end if
				$totalPrice += $price;
			} # end if
		} # end if


		if ( ( ! $$specs{"txtAdditionalCuts$form"} ) and $$sig_specs{txtPressSheetComboItems} ) {
			$$specs{"txtAdditionalCuts$form"} = $$sig_specs{txtPressSheetComboItems};
		} # end if

		if ( $$specs{"txtAdditionalCuts$form"} ) {
			$sheets = ceil( $$sig_specs{'txtQuantity'.$qty_index} / $$I{imposition} );
			my $runs = $liftDepth ? ceil( $sheets*$calliper/$liftDepth ) : $sheets;
			my $price = ( $runs * $$specs{"txtAdditionalCuts$form"} * $ServicePrice{price} );
			$results{Breakdown} .= 'Additional cuts:<br/>';
			$results{Breakdown} .= sprintf('%d cuts on %d sheets: $%.2f<br/>', $$specs{"txtAdditionalCuts$form"}, $sheets, $price );
			$totalPrice += $price;
		} # end if

		$mprice = $totalPrice;

		if ( $cuts ) {
			if ( $CuttingMakeReady ) {
				my %setup = $CuttingMakeReady->get_price( undef, $Equipment );
				$results{Breakdown} .= sprintf('Make Ready: $%.2f<br/>', $setup{price} );
				$totalPrice += $setup{price};
			} # end if
			if ( $Paper->bladecleaning() and $BladeCleaning ) {
				my %cleaning = $BladeCleaning->get_price( undef, $Equipment );
				$results{Breakdown} .= sprintf('Blade Cleaning: $%.2f<br/>', $cleaning{price} );
				$totalPrice += $cleaning{price};
				$mprice += $cleaning{price};
			} # end if
		} # end if
		$results{Breakdown} .= sprintf('Total: $%.2f<br/>', $totalPrice );
		if ( ( ! $bestEquipment ) or ( $bestPrice > $totalPrice ) ) {
			$bestM = $mprice;
			$bestPrice = $totalPrice;
			$bestEquipment = $Equipment;
		} # end if
	} # end for each equipment
		if ( $stitching_specs ) {
			# Need final trim?
			my @remaining_sides = sets::exclude( [ keys %pretrim_sides ], [ 'Head','Foot','Face' ] );
$log->debug("Final trim @remaining_sides") if DEBUG;
			if ( @remaining_sides ) {
				
			}	
		} # end if

	$results{Status}	= $bestEquipment ? 'calculated' : 'uncalculated';
	$results{Price}		= $bestPrice;
	$results{MPrice}	= ($bestM/$$specs{'txtQuantity'.$qty_index})*1000;
	$results{Equipment}	= $bestEquipment;
	if ( $bestEquipment and ( my $Spec = $bestEquipment->Specification('Cutting Overs') ) ) {
		if ( $$Spec{units} eq 'Sheets' ) {
			$results{Overs} = $$Spec{value};
		} # end if
	} # end if
	return %results;
} # end sub signature_calc

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	$$specs{Status} = 'calculated';

	if ( ! $$specs{txtNameQuantity} ) {
		$$specs{txtNameQuantity} = 1;
	} # end if

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	
	my $fold_specs = openprint::service::get_specs_ref( $Project, $$services{Folding}[0] ) if $$services{Folding} and @{$$services{Folding}};
	my $calc_hash = {};

	my @signatures = $Project->signatures({sort=>1});
	if ( ! @signatures ) {
		$openprint::log->error('ONo signatures');
	} # end if

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! int($$specs{"txtQuantity$qty_index"}) ) {
			$openprint::log->debug("No quantity for $qty_index");
			next;
		} # end if

		$$specs{'hdnBreakdown'.$qty_index} = '';
		my $price;
		my $mprice;

		my %Cut_Stocks;

# For the non-book case, this devolves into the printing service
		foreach my $signature_service_index ( @signatures ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			my $form = $$sig_specs{SignatureIndex};
			$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $form $$sig_specs{txtSignatureType}<br/>";
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'no imposition.';
				$$specs{"txtRegularCutPrice-$form-$qty_index"} = '';
				$$specs{"ddmEquipment-$form-$qty_index"}  = '';
				$$specs{"txtVerticalCuts-$form-$qty_index"} = '';
				$$specs{"txtHorizontalCuts-$form-$qty_index"} = '';
				$$specs{"txtDVerticalCuts-$form-$qty_index"} = '';
				$$specs{"txtDHorizontalCuts-$form-$qty_index"} = '';
				$$specs{"txtCalculatedCuts-$form-$qty_index"} = '';
				next;
			} # end if
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index );
			next if ! $Imposition->imposition();
			my $Paper = $Imposition->Paper();
			if ( $Paper->type() eq 'Sheet' and $Paper->is_cut() ) {
				if ( $Cut_Stocks{ $Paper->id_string() } ) {
					$Cut_Stocks{ $Paper->id_string() }{quantity} += $$sig_specs{"StockQuantity$qty_index"};
				} else {
					$Cut_Stocks{ $Paper->id_string() } = { Stock=>$Paper, quantity=>$$sig_specs{"StockQuantity$qty_index"} };
				} # end if
			} # end if
$openprint::log->debug("Paper: " . $Paper->to_string() ) if DEBUG;

			# Folding
			if ( 0 and $$services{Folding} and @{$$services{Folding}} ) {
				my %results = signature_calc_folding_cutting( $Project, $sig_specs, $specs, $qty_index, $Paper, $Imposition, $fold_specs, $calc_hash );
				$$specs{"ddmFoldCutEquipment-$form-$qty_index"} = $results{Equipment} ? $results{Equipment}->id() : '';
				$$specs{"txtFoldCutPrice-$form-$qty_index"} = $results{Price};
				$price += $results{Price};
				$mprice += $results{MPrice};
				$$specs{Status} = 'uncalculated' if $results{Status} eq 'uncalculated';
				$$specs{alert} .= $results{alert};
				$$specs{'hdnBreakdown'.$qty_index} .= $results{Breakdown};
#$openprint::log->warn("Status from sig_calc_folding: $results{Status}");
			} # end if

			my %results = signature_calc( $Project, $sig_specs, $specs, $qty_index, $Paper, $Imposition, $fold_specs, $calc_hash );
			$$specs{Status} = 'uncalculated' if $results{Status} eq 'uncalculated';
			$$specs{alert} .= $results{alert} if $results{alert};
			$$specs{'hdnBreakdown'.$qty_index} .= $results{Breakdown};
			$$specs{"txtRegularCutPrice-$form-$qty_index"} = sprintf('%.2f', Math::Round::nearest( 0.01, $results{Price} ) );

			$$specs{"FoldingCutPrice-$form-$qty_index"} = sprintf('%.2f', Math::Round::nearest( 0.01, $results{FoldingPrice} ) );
			$$specs{"FoldingEquipment-$form-$qty_index"} = $results{FoldingEquipment} ? $results{FoldingEquipment}->id() : '';
			$$specs{"FoldingCuts-$form-$qty_index"} = $results{FoldingCuts};

			if ( my $minCharge = openprint::service::get_price( 'CuttingSignatureChargeMinimum', undef, $results{Equipment} ) ) {
				$results{Price} = $minCharge if $results{Price} and ($results{Price} < $minCharge);
			} # end if

			$price += $results{Price};
			$price += $results{FoldingPrice} if $results{FoldingPrice};

			$mprice += $results{MPrice};
			$$specs{"ddmEquipment-$form-$qty_index"} = $results{Equipment} ? $results{Equipment}->id() : '';
			$$specs{'hdnBreakdown'.$qty_index} .= '<hr/>';
		} # end foreach form

		if ( $$services{Paper} and %Cut_Stocks ) {
			my %results = signature_calc_stock_cutting( $Project, $specs, $qty_index, [ values %Cut_Stocks ] );
#$$specs{"ddmStockCutEquipment-$form-$qty_index"} = $results{Equipment} ? $results{Equipment}->id() : '';
			$$specs{"txtStockCutPrice-$qty_index"} = sprintf('%.2f', $results{Price} );
			$price += $results{Price};
			$mprice += $results{MPrice};
			$$specs{Status} = 'uncalculated' if $results{Status} eq 'uncalculated';
			$$specs{alert} .= $results{alert} if $results{alert};
			$$specs{'hdnBreakdown'.$qty_index} .= $results{Breakdown};
		} # end if
		if ( my $minCharge = openprint::service::get_price( 'CuttingChargeMinimum' ) ) {
			$price = $minCharge if $price and ($price < $minCharge);
		} # end if

		if ( $Project->markup() ) {
			my $markup = (1+$Project->markup()/100);
			$mprice *= $markup;
			$price *= $markup;
		} # end if
		if ( $$specs{'Markup'.$qty_index} ) {
			my $markup = (1+$$specs{'Markup'.$qty_index}/100);
			$mprice *= $markup;
			$price *= $markup;
		} # end if

		if ( (defined $$specs{"OverridePrice$qty_index"} ) and ( $$specs{"OverridePrice$qty_index"} eq 'Y' ) ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $config{ProjectMoneyFormat}, $$specs{"txtPrice$qty_index"} );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $config{ProjectMoneyFormat}, Math::Round::nearest( 1, $price ) );
		} # end if
		$$specs{"MPrice$qty_index"} = sprintf( $config{UnitPriceFormat}, $mprice );
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $config{UnitPriceFormat}, $price/$$specs{"txtQuantity$qty_index"});

	} # end foreach quantity
	return $$specs{Status};
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;
	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	@{$$variable{StockCutEquipmentArray}} = map { $_->id(), $_->name() } openprint::Equipment->find( 'Specifications' => {'Cutting Capable'=>'Y'}, 'useinestimating'=>1,'order'=>'lower(strName)');

	my @capabilities = ('Y','When Printing','When Folding');
	if ( $$services{SaddleStitching} or $$services{LoopStitching} ) {
		push @capabilities, 'When Stitching';
	} # end if
	if ( $$services{PerfectBound} ) {
		push @capabilities, 'When PerfectBinding';
	} # end if
	if ( sets::isin( $Project->Type()->name(), ['Banners','InkjetOutputs','Decals','Signs'] ) ) {
		push @capabilities, 'Large Format';
	} # end if

	$$variable{EquipmentArray} = [ map { $_->id(), $_->name() } openprint::Equipment->find( 'Specifications' => {'Cutting Capable'=>\@capabilities}, 'useinestimating'=>1,'order'=>'lower(strName)') ];
	$$variable{PreFoldingEquipmentArray} = [ map { $_->id(), $_->name() } openprint::Equipment->find( Specifications => {'Cutting Capable'=>['Y','When Printing']}, 'useinestimating'=>1,'order'=>'lower(strName)') ];


	@{$$variable{CuttingGroups}} = ();

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		my $form = $$sig_specs{SignatureIndex};
		push @{$$variable{CuttingGroups}}, $signature_service_index, @$sig_specs{'SignatureIndex','txtServiceDescription'};
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			next if $$sig_specs{'StockType'.$qty_index} eq 'Roll';
			@$variable{"txtSuppliedStockWidth-$form-$qty_index", "txtSuppliedStockHeight-$form-$qty_index",
				"txtSheetSizeWidth-$form-$qty_index", "txtSheetSizeHeight-$form-$qty_index"} =
				@$sig_specs{"hdnSuppliedStockWidth$qty_index","hdnSuppliedStockHeight$qty_index","StockWidth$qty_index","StockHeight$qty_index"};

		} # end foreach
	} # end foreach
	if ( @{$$variable{CuttingGroups}} == 0 ) {
# this will display the first group of cutting fields for projects that dont' have a printing service.
		push @{$$variable{CuttingGroups}}, 0;
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
	$Media->setAttribute( 'Brand', $$sig_specs{ddmStockBrand} );
	$Media->setAttribute( 'DescriptiveName', join(' ', @$sig_specs{'ddmStockBrand','ddmStockFinish','ddmStockColour','ddmStockWeight','StockWidth'.$Project->ordered_quantity_index(),$Project->ordered_quantity_index()} ) );
	$Media->setAttribute( 'Dimension', join(' ',
                $$sig_specs{'StockWidth'.$Project->ordered_quantity_index()}*25.4,# mm
                $$sig_specs{'StockHeight'.$Project->ordered_quantity_index()}*25.4,
			) );
	$Media->setAttribute( 'GrainDirection', 'LongEdge' );
	$Media->setAttribute( 'MediaType', 'Paper' );
	$Media->setAttribute( 'MediaUnit', 'Sheet' );
	$Media->setAttribute( 'Grade', '1' );
	$Media->setAttribute( 'Thickness', $$sig_specs{SpecificStockCalliper}*25.4 );
	$Media->setAttribute( 'Weight', $$sig_specs{'txtMWeight'.$Project->ordered_quantity_index()}*.45359237 );


	my $InputComponent = $ResourcePool->appendElement( $doc->createElement('Component') );
	$InputComponent->setAttribute( 'ID', 'CuttingInput'.$sig_id );
	$InputComponent->setAttribute( 'Class','Quantity' );
	$InputComponent->setAttribute( 'Status','Available' );
	$InputComponent->setAttribute( 'ComponentType','Sheet' );
	$InputComponent->setAttribute( 'Dimensions',join(' ', 
				$$sig_specs{'StockWidth'.$Project->ordered_quantity_index()}*25.4,
				$$sig_specs{'StockHeight'.$Project->ordered_quantity_index()}*25.4,
				$$sig_specs{SpecificStockCalliper}*25.4,
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
				$$sig_specs{txtWidth}*25.4,
				$$sig_specs{txtHeight}*25.4,
				$$sig_specs{SpecificStockCalliper}*25.4,
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

sub runspeed {
	my ( $Project, $Service, $Equipment, $qty_index, $signatures ) = @_;

	my $specs = $Service->specs();
	# Cutting Time is in seconds, so 3600/Cutting Time = # per hour
	my $cuttime = $Equipment->specification( 'Cutting Time' ) + $Equipment->specification( 'Make Ready Time' );
	return 0 if ! $cuttime;
	my $runspeed = 0;
	foreach my $sig_id ( @{$signatures} ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		next if ! $$sig_specs{txtSpecificStockCalliper};
		my $form = $$sig_specs{SignatureIndex};
		next if ! $$specs{"txtCalculatedCuts-$form-$qty_index"} or $$specs{"txtAdditionalCuts$form"};
		my $liftDepth = $Equipment->specification( 'Maximum Lift Depth', $$specs{txtSpecificationStockCalliper} );

		$runspeed += int(
			( $liftDepth / $$sig_specs{txtSpecificStockCalliper} ) * 
			3600/( $cuttime * ( $$specs{"txtCalculatedCuts-$form-$qty_index"} + $$specs{"txtAdditionalCuts$form"} ) ) );
#$openprint::log->debug( "Caclulationg runspeed for sig $sig_id $form) ( $$specs{"txtCalculatedCuts-$form-$qty_index"} )");
	} # end foreach
	return $runspeed;
}

sub runtime {
    my ( $Project, $Service, $Equipment, $qty_index, $impressions, $speed, $signatures ) = @_;

	my $specs = $Service->specs();
	my $runtime = 0;
	if ( ! $Equipment ) {
		return 0 if ! $$specs{'ddmEquipment'.$qty_index};
		$Equipment = openprint::Equipment->find_one('strid'=>$$specs{'ddmEquipment'.$qty_index});
		return 0 if ! $Equipment;
	} # end if

	my $makeready = $Equipment->specification( 'Make Ready Time' );
	my $runspeed = $Equipment->specification( 'Cutting Time' );
$openprint::log->debug("Cutting runtime: $makeready $runspeed");
	foreach my $sig_id ( @{$signatures} ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $sig_id );
		my $form = $$sig_specs{SignatureIndex};
		my $liftDepth = $Equipment->specification( 'Maximum Lift Depth', $$sig_specs{txtSpecificStockCalliper} );
$openprint::log->debug( "Caclulationg runspeed for sig $sig_id $form) (".$$specs{"txtCalculatedCuts-$form-$qty_index"} );
		$runtime += ( $$specs{"txtCalculatedCuts-$form-$qty_index"} + $$specs{"txtAdditionalCuts$form"} ) * ( $makeready + $runspeed) * ( $impressions/($liftDepth/$$sig_specs{txtSpecificStockCalliper} ) );
	} # end foreach
$openprint::log->debug("Cutting runtime: $runtime $impressions");
	return $runtime;
} # end sub runtime
sub save {
} # end sub save


1;
__END__
