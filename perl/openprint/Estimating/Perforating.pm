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

package openprint::Estimating::Perforating;
use strict;

require sql;
require openprint::service;
require openprint::Material;
require openprint::imposition;
require openprint::Imposition;
require openprint::project;

my $debug = 0;

my @all_equipment;
my @stitchers;

my @variables = (
	'txtQuantity1','txtQuantity2','txtQuantity3',
    'txtPrice1','txtPrice2','txtPrice3',
);
sub variables {
	my $p_id = shift;
	my @v = @variables;

	my $Project = new openprint::Project( $p_id );
	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		
		foreach my $qty_index ( 1 .. 3 ) {
			next if ! $$sig_specs{'txtQuantity'.$qty_index};
			push @v, (
				 "txtVerticalQty-$$sig_specs{'SignatureIndex'}", "VerticalTeeth-$$sig_specs{SignatureIndex}",
				 "txtHorizontalQty-$$sig_specs{'SignatureIndex'}", "HorizontalTeeth-$$sig_specs{SignatureIndex}",
				 "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index", "chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
				 "txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index", "chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index",
				 "txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index",
				 );
		} # end foreach qty_index
	} # end foreach signature_service_index
	return @v;
} # end sub variables

my @no_output = (
	
);

sub no_outputs {
	return @no_output;
}


# A function that is smart enough to return true if the project needs perfing, and false if it doesn't.
sub neccessary {
	my ( $log, $dbh, $Project ) = @_;

    #$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';
#
    #my %services = $Project->get_services( );
    #if ( $services{'NoBindery'} ) {
        #$log->debug(" ** Project is marked as No bindery, Perforating not needed ! ** ");
        #return 0;
    #} # end if

	#$log->debug("PERF NOT NEEDED!");
	return 0;
} # end sub neccessary


sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );

	$log->debug("BEGIN PERFING!!!!!!!!!!!!!!!!!!");
	if ( $Project->Type()->strid() eq 'MultiPagePublication'  ) {
		$$specs{'alert'} = 'We are unable to auto-calculate a price for perforation on a multipage publication. Please call for pricing.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! $$specs{"txtQuantity$qty_index"} > 0 ) {
			next;
		} # end if

		$$specs{'hdnBreakdown'.$qty_index} = qq`QTY $qty_index ( $$specs{"txtQuantity$qty_index"} )<br/>`;
		my $qty = $$specs{"txtQuantity$qty_index"};
		if ( $$specs{'txtPressSheetComboItems'} ) {
			$qty *= $$specs{'txtPressSheetComboItems'};
		} # end if

		my $totalServicePrice = 0;
		my $totalSetupPrice = 0;
		my $totalMaterialPrice = 0;
		my $qtyTotal = 0;

		foreach my $signature_service_index ( $Project->signatures() ) {
            my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
			my %Price = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index );
			$status = $Price{'Status'};
            $qtyTotal += $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"};
            $qtyTotal += $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"};
            $totalSetupPrice += $Price{'SetupPrice'};
            $totalServicePrice += $Price{'ServicePrice'};
            $totalMaterialPrice += $Price{'MaterialPrice'};
		} # end foreach signature

		my $price = 0;
		my $unitPrice = 0;

		if ( $qtyTotal ) {
			$price = $totalSetupPrice + $totalServicePrice + $totalMaterialPrice;
			$unitPrice = $price / $qty;
		} else {
			$$specs{'alert'} .= 'Please specify # of perfs';
			$status = 'uncalculated';
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $unitPrice );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
	} # end foreach quantities

	$log->debug("END PERFING!!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

sub signature_calc {
    my ( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index ) = @_;
	$$specs{'hdnBreakdown'.$qty_index} .= qq`Signature: $$sig_specs{'SignatureIndex'}<br/>`;

	my $qty = $$specs{"txtQuantity$qty_index"};
	if ( $$sig_specs{'PageQuantity'} ) {
		$qty *= $$sig_specs{'PageQuantity'};
	} # end if

    $specs = openprint::service::get_specs_ref( $Project, $service_index ) if ! $specs;
    $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index ) if ! $sig_specs;

    my %Results = (
        'Status' => 'calculated',
    );

	my $services = $Project->services();

	my $scoring_service_index = $$services{'Scoring'}[0] if $$services{'Scoring'};
	my $cutting_service_index = $$services{'Cutting'}[0] if $$services{'Cutting'};
# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	my $stitching_service_index = $$services{'SaddleStitching'}[0] if $$services{'SaddleStitching'};
# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	$stitching_service_index = $$services{'LoopStitching'}[0] if ( ! $stitching_service_index) and $$services{'LoopStitching'};

	@all_equipment = openprint::Equipment::find( 'Specifications' => {'Perforating Capable'=>'Y'}, 'UseInEstimating'=>'Y') if ! @all_equipment;
	@stitchers = openprint::Equipment::find( 'Specifications' => {'Stitching Capable'=>'Y'}, 'UseInEstimating'=>'Y') if ! @stitchers;
	my @equipment;

	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@equipment = openprint::Equipment::find( 'strid'=>$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
		$openprint::log->debug("Overriding Equipment to: " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
	} elsif ( ! $stitching_service_index ) {
		@equipment = sets::exclude( \@stitchers, \@all_equipment );
	} else {
		@equipment = @all_equipment;
	} # end if

	@no_output = sets::union( @no_output,
			"txtVerticalQty-$$sig_specs{'SignatureIndex'}", 
			"txtHorizontalQty-$$sig_specs{'SignatureIndex'}", 
			"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
			"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index",
			( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ? "txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index" : () ),
			);
	
	$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';

	@$specs{"txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};

	my $rule_qty = $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} + $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"};
	if ( ! $rule_qty ) {
		return %Results;
	} # end if

# If any of the signatures doesn't have an imposition, then we are in an incomplete state.
	if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
		$$specs{'alert'} = 'Printing calculations are not complete.';
		$Results{'Status'} = 'uncalculated';
		return %Results;
	} # end if

	my $bestPrice = 0;
	my $bestEquipment = '';
	my $bestSetupPrice = 0;
	my $bestMaterialPrice = 0;
	my $bestServicePrice = 0;
	my $bestImposition;

	my $imposition = new openprint::Imposition();
	$imposition->load( $sig_specs, $qty_index );

	if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > $imposition->imposition() or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
			$$specs{'alert'} = "The specified imposition is not possible.";
			$Results{'Status'} = 'uncalculated';
			return %Results;
		} # end if
	} # end if

	my @cut_impositions = ();
	if ( $cutting_service_index ) {
		my @imps = openprint::imposition::get_all_impositions( $imposition );
		for ( my $i = 0; $i < @imps; $i += 1 ) {
			if ( ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' )
					or ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} == $imps[$i]->imposition() )
			   ) {
				push @cut_impositions, $imps[$i];
			} # end if
			for ( my $j = $i + 1; $j < @imps; $j += 1 ) {
				if ( $imps[$i]->imposition() == $imps[$j]->imposition() and $imps[$i]->rows() == $imps[$j]->rows() ) {
					splice @imps, $j, 1;
					$j -= 1;
				} # end if
			} # end foreach
		} # end foreach
	} else {
		@cut_impositions = ( $imposition );
	} # end if

	my ( $scor_equipment, $scor_imposition );
	if ( $scoring_service_index ) {
		( $scor_equipment, $scor_imposition ) = openprint::service::get_specifications( $openprint::log, $openprint::dbh, $Project->id(), $scoring_service_index, "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index", "txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index" );
		if ( ! $scor_equipment ) {
			$openprint::log->debug("No equipment selected for scoring.  Quitting.");
			$$specs{'alert'} = 'Scoring calculations are not complete.  Your project contains a scoring service.  It must be completed before the Perforation service.';
			$Results{'Status'} = 'uncalculated';
			return %Results;
		} # end if
	} # end if

	foreach my $Equipment ( @equipment ) {
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf("\t\tEquipment: %s, ", $Equipment->name() );

		my @impositions = ();
		if ( $Equipment->specification('Type') eq 'Press' ) {
			@impositions = ($imposition);
			if ( ( $Equipment->specification('WTPerforation') ne 'Y' ) and sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble'] ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Cant do an inline perf when W&T.<br/>';
				next;
			} # end if
		} else {
			@impositions = @cut_impositions;
		} # end if

		my $setupPrice = openprint::service::get_price( 'PerforationMakeReady', undef, $Equipment );
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf( 'Setup: $%.2f<br/>', $setupPrice);

		foreach my $imposition ( @impositions ) {
			$$specs{'hdnBreakdown'.$qty_index} .= "Imposition: " . $imposition->imposition() .": ";
			my $width = $imposition->layout_width();
			my $height = $imposition->layout_height();

# If it's a press, then we can assume that it fits.
			if ( $Equipment->specification('Type') ne 'Press' and $_ = $Equipment->fits( $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "$_<br/>";
				next;
			} # end if

			my %servicePrice;
			my $servicePrice;
			my %materialPrice;
			my $materialPrice = 0;


			if ( $scor_equipment eq $Equipment->strid() and $scor_imposition == $imposition->imposition() ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "\tSame equipment as scoring, no service price needed.<br/>";
			} else {
				%servicePrice = openprint::service::get_price_object( 'Perforating', $rule_qty, $Equipment );
# I don't know if we should be multiplying by this or not.. how many perfs can a given piece of equipment do in an impression?
#$servicePrice *= $$specs{"txtQty-$signature_index"};
			} # end if

			if ( lc $servicePrice{'units'} eq 'per m' ) {
				$servicePrice = $servicePrice{'Price'} * ($qty/$imposition->imposition())/ 1000;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: $%.2f%s * %d = $%.2f<br/>', @servicePrice{'Price','units'}, $qty/$imposition->imposition(), $servicePrice );
			} elsif ( lc $servicePrice{'units'} eq 'per hour' ) {
				if ( int ( $_ = $Equipment->specification('PerfScoreRunSpeed') ) ) {
					my $hours = $qty / $Equipment->specification('PerfScoreRunSpeed');
					$servicePrice = $servicePrice{'Price'} * $hours;
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: $%.2f%s @ %d%s = $%.2f<br/>', @servicePrice{'Price','units'}, $Equipment->specification('PerfScoreRunSpeed'), 'Per Hour', $servicePrice );
			} # end if

			if ( my @Materials = openprint::Material::find('name'=>'PerforatingRule') ) {
				%materialPrice = $Materials[0]->get_price( $rule_qty, $Equipment );
				if ( $materialPrice{'units'} eq 'Per Rule' ) {
					$materialPrice = $materialPrice{'Price'} * $rule_qty;
				} elsif ( lc $materialPrice{'units'} eq 'per inch' ) {
					my $length = ( $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} + $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} * $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} );
					$materialPrice = $materialPrice{'Price'} * $length;
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material: $%.2f%s * %.2finches=%.2f', @materialPrice{'Price','units'}, $length, $materialPrice );
				} elsif ( $materialPrice{'units'} eq 'per foot' ) {
					my $length = ( $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} + $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} * $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} ) /12;
					$materialPrice = $materialPrice{'Price'} * $length;
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material: $%.2f%s * %.2ffeet=%.2f', @materialPrice{'Price','units'}, $length, $materialPrice );
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units set on material price ($materialPrice{'units'})<br/>";
				} # end if
			} # end if

			my $totalPrice = $setupPrice + $materialPrice + $servicePrice;
			$$specs{'hdnBreakdown'.$qty_index} .= "\t\tTotal: \$".sprintf('%.2f', int($totalPrice) )."<br/>";

			if ( $totalPrice < $bestPrice or $bestPrice == 0 ) {
				$bestPrice = $totalPrice;
				$bestSetupPrice = $setupPrice;
				$bestMaterialPrice = $materialPrice;
				$bestServicePrice = $servicePrice;
				$bestEquipment = $Equipment;
				$bestImposition = $imposition;
			} # end if
		} # end foreach imposition
	} # end foreach equipment

	$Results{'SetupPrice'} = $bestSetupPrice;
    $Results{'ServicePrice'} = $bestServicePrice;
    $Results{'MaterialPrice'} = $bestMaterialPrice;
    $Results{'Price'} = $bestSetupPrice + $bestServicePrice + $bestMaterialPrice;

	if ( $bestImposition ) {
		$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestEquipment->strid();
		$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestImposition->imposition();
		$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestImposition->layout_width();
		$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestImposition->layout_height();
	} else {
		$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '' if $$specs{"chkOverrideEquipment-$$sig_specs{SignatureIndex}-$qty_index"} ne 'Y';
		$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
		$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
		$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
	} # end if
	if ( ! $bestEquipment ) {
		$Results{'Status'} = 'uncalculated';
		if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
			$$specs{'alert'} = "The selected equipment can not handle your project.  This may be because the stock is too heavy, or too large.";
		} else {
			$$specs{'alert'} = "No suitable equipment could be found for your project.  This may be because the stock is too heavy, or too large.";
		} # end if
	} # end if
	return %Results;
} # end sub signature_calc

sub get_specs {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	@{$$variable{'SignatureGroups'}} = ();

	@{$$variable{'EquipmentArray'}} = map{ $_->id() } openprint::Equipment::find( 'Specifications' => {'Perforating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'strName');

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		push @{$$variable{'SignatureGroups'}}, @$sig_specs{'SignatureIndex','txtServiceDescription'};
	} # end foreach

} # end sub get_scoring_specs

sub fits_on_equipment {
    my ( $log, $dbh, $equipment_specs, $width, $height, $calliper ) = @_;

    if ( $$equipment_specs{'Minimum Perforation Size'} and ( 1*$width < 1*$$equipment_specs{'Minimum Perforation Size'} ) ) {
        $log->debug("Doesn't fit width minimum");
        return 0;
    } # end if

    if ( $$equipment_specs{'Minimum Perforation Size'} and ( 1*$height < 1*$$equipment_specs{'Minimum Perforation Size'} ) ) {
        $log->debug("Doesn't fit height minimum");
        return 0;
    } # end if
    if ( $$equipment_specs{'Maximum Perforation Size'} and ( 1*$width > 1*$$equipment_specs{'Maximum Perforation Size'} ) ) {
        $log->debug("Doesn't fit width maximum");
        return 0;
    } # end if

    if ( $$equipment_specs{'Maximum Perforation Size'} and ( 1*$height > 1*$$equipment_specs{'Maximum Perforation Size'} ) ) {
        $log->debug("Doesn't fit height max");
        return 0;
    } # end if
    if ( $$equipment_specs{'Minimum Perforation Calliper'} and 1*$calliper < 1*$$equipment_specs{'Minimum Perforation Calliper'} ) {
        $log->debug("Calliper too small Calliper: ($calliper), Min: $$equipment_specs{'Minimum Perforation Calliper'}");
        return 0;
    } # end if
    if ( $$equipment_specs{'Maximum Perforation Calliper'} and 1*$calliper > 1*$$equipment_specs{'Maximum Perforation Calliper'} ) {
        $log->debug("Calliper too big");
        return 0;
    } # end if
    return 1;

} # end sub fits_on_equipment

sub summary {
	return '';
} # end sub summary

1;

__END__
