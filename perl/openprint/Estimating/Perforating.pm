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
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1', 'Markup2', 'Markup3',
);
sub variables {
	my $p_id = shift;
	my @v = @variables;

	my $Project = new openprint::Project( $p_id );
	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		
		foreach my $qty_index ( $Project->quantity_indexes() ) {
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
	my ( $Project ) = @_;

    $Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';
	return 1 if ( $Project->signatures({'type'=>'PerfReplyCard'}) );
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

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! $$specs{"txtQuantity$qty_index"} > 0 ) {
			next;
		} # end if

		$$specs{'hdnBreakdown'.$qty_index} = qq`QTY $qty_index ( $$specs{"txtQuantity$qty_index"} )<br/>`;
		my $qty = $$specs{"txtQuantity$qty_index"};
		if ( $$specs{'txtPressSheetComboItems'} ) {
			$qty *= $$specs{'txtPressSheetComboItems'};
		} # end if

		my $qtyTotal = 0;
		my $price = 0;

		foreach my $signature_service_index ( $Project->signatures() ) {
            my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );

			@no_output = sets::union( @no_output,
					"txtVerticalQty-$$sig_specs{'SignatureIndex'}", 
					"txtHorizontalQty-$$sig_specs{'SignatureIndex'}", 
					"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
					"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index",
					( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ? "txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index" : () ),
					);

# If any of the signatures doesn't have an imposition, then we are in an incomplete state.
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'alert'} = 'Printing calculations are not complete.';
				$status = 'uncalculated';
				next;
			} # end if
			my %Price = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index );
			if ( ! ( $$specs{"txtVerticalQty-$$sig_specs{SignatureIndex}"} or $$specs{"txtHorizontalQty-$$sig_specs{SignatureIndex}"} ) ) {
				$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				next;
			} # end if
			if ( $Price{'Equipment'} ) {
				$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Equipment'}->id();
				$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Imposition'}->imposition();
				$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Imposition'}->layout_width();
				$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $Price{'Imposition'}->layout_height();
				$status = $Price{'Status'};
			} else {
				$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '' if $$specs{"chkOverrideEquipment-$$sig_specs{SignatureIndex}-$qty_index"} ne 'Y';
				$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				$status = 'uncalculated';
				if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
					$$specs{'alert'} = "The selected equipment can not handle your project.  This may be because the stock is too heavy, or too large.";
				} else {
					$$specs{'alert'} = "No suitable equipment could be found for your project.  This may be because the stock is too heavy, or too large.";
				} # end if
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= $Price{'Breakdown'};
			$qtyTotal += $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"};
			$qtyTotal += $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"};
            $price += $Price{'SetupPrice'};
            $price += $Price{'ServicePrice'};
            $price += $Price{'VerticalPrice'}{'Total'};
            $price += $Price{'HorizontalPrice'}{'Total'};
		} # end foreach signature

		my $unitPrice = 0;

		if ( $qtyTotal ) {
			$unitPrice = $price / $qty;
		} else {
			$$specs{'alert'} .= 'Please specify # of perfs';
			$status = 'uncalculated';
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $unitPrice );
		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price*(1+$$specs{"Markup$qty_index"}/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
	} # end foreach quantities

	$log->debug("END PERFING!!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

sub signature_calc {
    my ( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $imposition ) = @_;

	my $qty = $$specs{"txtQuantity$qty_index"};
	if ( $$sig_specs{'PageQuantity'} ) {
		$qty *= $$sig_specs{'PageQuantity'};
	} # end if

    $specs = openprint::service::get_specs_ref( $Project, $service_index ) if ! $specs;
    $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index ) if ! $sig_specs;

    my %Results = (
        'Status' => 'calculated',
		'Breakdown'	 => "Signature: $$sig_specs{'SignatureIndex'}<br/>",
    );

	my $services = $Project->services();

	my $scoring_service_index = $$services{'Scoring'}[0] if $$services{'Scoring'};
	my $cutting_service_index = $$services{'Cutting'}[0] if $$services{'Cutting'};
# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	my $stitching_service_index = $$services{'SaddleStitching'}[0] if $$services{'SaddleStitching'};
# Can only use the stitcher for scoring if we are stitching.  There are also thickness constraints
	$stitching_service_index = $$services{'LoopStitching'}[0] if ( ! $stitching_service_index) and $$services{'LoopStitching'};

	if ( ! @all_equipment ) {
		@all_equipment = openprint::Equipment::find( 'Specifications' => {'Perforating Capable'=>'Y'}, 'UseInEstimating'=>'Y');
		push @all_equipment, openprint::Equipment::find( 'Specifications' => {'Perforating Capable'=>'When Printing'}, 'UseInEstimating'=>'Y');
	} # end if

	@stitchers = openprint::Equipment::find( 'Specifications' => {'Stitching Capable'=>'Y'}, 'UseInEstimating'=>'Y') if ! @stitchers;
	my @equipment;

	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@equipment = openprint::Equipment::find( 'id'=>$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
		$openprint::log->debug("Overriding Equipment to: " . $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
	} elsif ( ! $stitching_service_index ) {
		@equipment = sets::exclude( \@stitchers, \@all_equipment );
	} else {
		@equipment = @all_equipment;
	} # end if

	$Results{'Breakdown'} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';

	#@$specs{"txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};
	if ( ( $$sig_specs{'txtSignatureType'} eq 'PerfReplyCard' ) and ! ( $$specs{"txtVerticalQty-$$sig_specs{SignatureIndex}"} or $$specs{"txtHorizontalQty-$$sig_specs{SignatureIndex}"} ) ) {
		$$specs{"txtVerticalQty-$$sig_specs{SignatureIndex}"} = 1;
		@no_output = sets::exclude( [ "txtVerticalQty-$$sig_specs{'SignatureIndex'}" ], \@no_output );
	} # end if

	my $rule_qty = $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} + $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"};
	if ( ! $rule_qty ) {
		return %Results;
	} # end if

	if ( ! $imposition ) {
		$imposition = new openprint::Imposition();
		$imposition->load( $sig_specs, $qty_index );
	} else {
		$imposition = $imposition->copy();
	} # end if

	if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > $imposition->imposition() or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
			$$specs{'alert'} = 'The specified imposition is not possible.';
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
		my $score_specs = openprint::service::get_specs_ref( $Project, $scoring_service_index );

		( $scor_equipment, $scor_imposition ) = @$score_specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index", "txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"};
		if ( ( $$score_specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} or $$score_specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} ) and ! $scor_equipment ) {
			$openprint::log->debug("No equipment selected for scoring.  Quitting.");
			$$specs{'alert'} = 'Scoring calculations are not complete.  Your project contains a scoring service.  It must be completed before the Perforating service.';
			$Results{'Status'} = 'uncalculated';
			return %Results;
		} # end if
	} # end if

	foreach my $Equipment ( @equipment ) {
		$Results{'Breakdown'} .= sprintf("\t\tEquipment: %s, ", $Equipment->name() );

		my @impositions = ();
		if ( $Equipment->specification('Type') eq 'Press' ) {
			@impositions = ($imposition);
			if ( ( $Equipment->specification('WTPerforation') ne 'Y' ) and sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble'] ) ) {
				$Results{'Breakdown'} .= 'Cant do an inline perf when W&T.<br/>';
				if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
					$$specs{'alert'} = "Can't do an inline perf when W&T.  After saving, printing will be recalculated.";
					$Results{'Equipment'} = $Equipment;
					$Results{'Status'} = 'uncalculated';
					return %Results;	
				} # end if
				next;
			} # end if
		} else {
			@impositions = @cut_impositions;
		} # end if
		if ( $$services{'NoOfflineBindery'} and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$Results{'Breakdown'} .= "No Offline bindery and not printing on $$Equipment{name}.<br/>";
			next;
		} # end if
		if ( ($Equipment->specification('Perforating Capable') eq 'When Printing' ) and ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) ) {
			$Results{'Breakdown'} .= "Not printing on $$Equipment{name}.<br/>";
			next;
		} # end if

		my $setupPrice = openprint::service::get_price( 'PerforatingMakeReady', undef, $Equipment );
		$Results{'Breakdown'} .= sprintf( 'Setup: $%.2f<br/>', $setupPrice);

		foreach my $imposition ( @impositions ) {
			$Results{'Breakdown'} .= "Imposition: " . $imposition->imposition() .": ";
			my $width = $imposition->layout_width();
			my $height = $imposition->layout_height();

# If it's a press, then we can assume that it fits.
			if ( $Equipment->specification('Type') ne 'Press' and $_ = $Equipment->fits( $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
				$Results{'Breakdown'} .= "$_<br/>";
				next;
			} # end if

			my %servicePrice;
			my $servicePrice;

			if ( $scor_equipment eq $Equipment->strid() and $scor_imposition == $imposition->imposition() ) {
				$Results{'Breakdown'} .= "\tSame equipment as scoring, no service price needed.<br/>";
			} else {
				%servicePrice = openprint::service::get_price_object( 'Perforating', $rule_qty, $Equipment );
# I don't know if we should be multiplying by this or not.. how many perfs can a given piece of equipment do in an impression?
#$servicePrice *= $$specs{"txtQty-$signature_index"};
			} # end if

			if ( lc $servicePrice{'units'} eq 'per m' ) {
				$servicePrice = $servicePrice{'Price'} * ($qty/$imposition->imposition())/ 1000;
				$Results{'Breakdown'} .= sprintf('Service: $%.2f%s * %d = $%.2f<br/>', @servicePrice{'Price','units'}, $qty/$imposition->imposition(), $servicePrice );
			} elsif ( lc $servicePrice{'units'} eq 'per hour' ) {
				if ( int ( $_ = $Equipment->specification('PerfScoreRunSpeed') ) ) {
					my $hours = $qty / $Equipment->specification('PerfScoreRunSpeed');
					$servicePrice = $servicePrice{'Price'} * $hours;
				} # end if
				$Results{'Breakdown'} .= sprintf('Service: $%.2f%s @ %d%s = $%.2f<br/>', @servicePrice{'Price','units'}, $Equipment->specification('PerfScoreRunSpeed'), 'Per Hour', $servicePrice );
			} # end if
# Div by imposition
			$servicePrice /= $imposition->imposition() if $imposition->imposition();


			my $horizontal_rule = 0;
			my $horizontal_length = 0;
			my %horizontal_price;

			if ( $imposition->image_orientation() eq 'Vertical' and  $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} ) {
				$horizontal_rule = $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $imposition->rows();
				$horizontal_length = $horizontal_rule * $$sig_specs{'txtWidth'};
			} elsif ( $imposition->image_orientation() eq 'Horizontal' and  $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} ) {
				$horizontal_rule = $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} * $imposition->columns();
				$horizontal_length = $horizontal_rule * $$sig_specs{'txtHeight'};
			} # end if
		#$openprint::log->debug("Horizontal: $horizontal_rule");	
			if ( $horizontal_rule ) {
				if ( my @Materials = openprint::Material::find('name'=>'PerforatingRule') ) {
					%horizontal_price = $Materials[0]->get_price( $horizontal_rule, $Equipment );
					if ( sets::isin( lc $horizontal_price{'units'},['per rule','each'] ) ) {
						$horizontal_price{'Total'} = $horizontal_price{'Price'} * $horizontal_rule;
						$Results{'Breakdown'} .= sprintf('Rule: $%1$.2f%2$s * %4$d rule=%3$.2f', @horizontal_price{'Price','units','Total'}, $horizontal_rule );
					} elsif ( lc $horizontal_price{'units'} eq 'per inch' ) {
						$horizontal_price{'Total'} = $horizontal_price{'Price'} * $horizontal_length;
						$Results{'Breakdown'} .= sprintf('Rule: $%1$.2f%2$s * %4$.2finches=%3$.2f', @horizontal_price{'Price','units','Total'}, $horizontal_length );
					} elsif ( $horizontal_price{'units'} eq 'per foot' ) {
						$horizontal_price{'Total'} = $horizontal_price{'Price'} * $horizontal_length/12;
						$Results{'Breakdown'} .= sprintf('Rule: $%1$.2f%2$s * %4$.2finches=%3$.2f', @horizontal_price{'Price','units','Total'}, $horizontal_length/12 );
					} else {
						$Results{'Breakdown'} .= "Unknown units set on rule price ($horizontal_price{'units'})<br/>";
					} # end if
				} # end if
			} # end if

			my $vertical_rule = 0;
			my $vertical_length = 0;
			my %vertical_price;
			
			if ( $imposition->image_orientation() eq 'Vertical' and  $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} ) {
				$vertical_rule = $$specs{"txtVerticalQty-$$sig_specs{'SignatureIndex'}"} * $imposition->columns();
				$vertical_length = $vertical_rule * $$sig_specs{'txtHeight'};
			} elsif ( $imposition->image_orientation() eq 'Horizontal' and  $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} ) {
				$vertical_rule = $$specs{"txtHorizontalQty-$$sig_specs{'SignatureIndex'}"} * $imposition->rows();
				$vertical_length = $vertical_rule * $$sig_specs{'txtWidth'};
			} # end if

		#$openprint::log->debug("Vertical: $vertical_rule");	
			if ( $vertical_rule ) {
				if ( my @Materials = openprint::Material::find('name'=>'ScoringWheel') ) {
					%vertical_price = $Materials[0]->get_price( $vertical_rule, $Equipment );
					if ( sets::isin( lc $vertical_price{'units'},['per rule','each'] ) ) {
						$vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_rule;
						$Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f2$%s * %4$d wheels=%3$.2f', @vertical_price{'Price','units','Total'}, $vertical_rule );
					} elsif ( lc $vertical_price{'units'} eq 'per inch' ) {
						$vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_length;
						$Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f2$%s * %4$.2finches=%3$.2f', @vertical_price{'Price','units','Total'}, $vertical_length );
					} elsif ( $vertical_price{'units'} eq 'per foot' ) {
						$vertical_price{'Total'} = $vertical_price{'Price'} * $vertical_length/12;
						$Results{'Breakdown'} .= sprintf('Wheel: $%1$.2f2$%s * %4$.2finches=%3$.2f', @vertical_price{'Price','units','Total'}, $vertical_length/12 );
					} else {
						$Results{'Breakdown'} .= "Unknown units set on wheel price ($vertical_price{'units'})<br/>";
					} # end if
				} # end if
			} # end if

			my $totalPrice = $setupPrice + $vertical_price{'Total'} + $horizontal_price{'Total'} + $servicePrice;
			$Results{'Breakdown'} .= sprintf('Total: $%.2f<br/>', int($totalPrice) );

			if ( $totalPrice < $Results{'Price'} or ! exists $Results{'Price'} ) {
				$Results{'Price'} = $totalPrice;
				$Results{'SetupPrice'} = $setupPrice;
				$Results{'ServicePrice'} = $servicePrice;
				$Results{'HorizontalPrice'} = \%horizontal_price;
				$Results{'VerticalPrice'} = \%vertical_price;
				$Results{'Equipment'} = $Equipment;
				$Results{'Imposition'} = $imposition;
				$Results{'Runspeed'} = $Equipment->specification('Perforating Runspeed');
			} # end if
		} # end foreach imposition
	} # end foreach equipment
	if ( $Results{'Equipment'} ) {
		$Results{'Status'} = 'calculated';
	} else {
		$Results{'Status'} = 'uncalculated';
	} # end if
	return %Results;
} # end sub signature_calc

sub get_specs {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	@{$$variable{'SignatureGroups'}} = ();

	@{$$variable{'Equipment'}} = openprint::Equipment::find( 'Specifications' => {'Perforating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'strName');
	push @{$$variable{'Equipment'}}, openprint::Equipment::find( 'Specifications' => {'Scoring Capable'=>'When Printing'}, 'UseInEstimating'=>'Y','order'=>'strName');

	if ( $$services{'Folding'} ) {
		push @{$$variable{'Equipment'}}, openprint::Equipment::find( 'Specifications' => {'Scoring Capable'=>'When Folding'}, 'UseInEstimating'=>'Y','order'=>'strName');
	} # end if

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
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
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	return '';
} # end sub summary

1;

__END__
