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

package openprint::Estimating::DieCutting;
use strict;

require openprint::project;
require openprint::Equipment;
require openprint::service;
require openprint::print;

require sql;

my @variables = (
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'txtSteelRuleLength','txtDieCutBends','txtHoleClearingHoles',
	'rdbSuppliedDie','txtDieCutPunches',
	'rdbDieCutting',
	'OverridePrice1','OverridePrice2','OverridePrice3',
	'txtPrice1','txtPrice2','txtPrice3',
	'DiePrice1','DiePrice2','DiePrice3',
	'OverrideDiePrice',
);

sub variables {
    return @variables;
} # end sub variables

my @output = (
);

sub get_output {
	return @output;
} # end sub get_output

sub calc_price {
    my ( $log, $dbh, $variable, $specs, $Equipment, $qty_index, $imposition ) = @_;

	my %Total;

	my %MakeReady = openprint::service::get_price_object( 'DieCutting'.$$specs{'rdbDieCutting'}.'MakeReady' ,'', $Equipment);
	if ( ! %MakeReady ) {
		%MakeReady = openprint::service::get_price_object( 'DieCuttingMakeReady' ,'', $Equipment);
	} # end if
	$Total{'MakeReady'} = \%MakeReady;
	$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;MakeReady: $%.2f<br/>', $MakeReady{'Price'});
	$Total{'Total'} += $MakeReady{'Price'};

	my %DiePrice;
	if ( $$specs{'rdbSuppliedDie'} eq 'Y' ) {
		# if customer is supplying die, then there is no die cost.
		$log->debug(" ** Customer is Supplying Die ** ");
	} else { 
		if ( $$specs{'rdbTemplateType'} ) {
# check for a standard die.
			if ( my @Materials = openprint::Material::find('name'=>$$specs{'rdbTemplateType'}.'Die') ) {
				%DiePrice = $Materials[0]->get_price( undef, $Equipment );
			} # end if
		} # end if
		if ( ( ! %DiePrice ) and $$specs{'rdbDieCutting'} ) {
			if ( my @Materials = openprint::Material::find('name'=>$$specs{'rdbDieCutting'}.'Die') ) {
				%DiePrice = $Materials[0]->get_price( undef, $Equipment );
			} # end if
		} # end if
			
		if ( ! %DiePrice ) {
			my %BendingPrice = openprint::service::get_price_object( 'DieCutRuleBending',$$specs{'txtDieCutBends'}*$imposition, undef );
			$BendingPrice{'Total'} = $BendingPrice{'Price'} * $$specs{'txtDieCutBends'} * $imposition;
			$DiePrice{'Price'} += $BendingPrice{'Total'};
#$die_price += $bending_price;
#$log->debug(" ** Adding Bending Cost: $bending_price For $$specs{'txtDieCutBends'} Bends, MakeReady Total: $make_ready ** ");
			if ( my @Materials = openprint::Material::find('name'=>'DieCuttingDieRule') ) {
				my %SteelRulePrice = $Materials[0]->get_price( $$specs{'txtSteelRuleLength'}*$imposition, undef );
				$SteelRulePrice{'Total'} = $SteelRulePrice{'Price'} * $$specs{'txtSteelRuleLength'}*$imposition;
				$DiePrice{'Price'} += $SteelRulePrice{'Total'};
			} # end if
#$die_price += $steel_rule_price;
#$log->debug(" ** Adding Rule Cost: $steel_rule_price For $$specs{'txtSteelRuleLength'} Inches, MakeReady Total: $make_ready ** ");
#
			if ( $$specs{'txtDieCutPunches'} > 0 ) {
##punches are optional
				if ( my @Materials = openprint::Material::find('name'=>'DieCutPunch'.$$specs{'rdbDieCutting'}) ) {
					my %PunchPrice = $Materials[0]->get_price( $$specs{'txtDieCutPunches'}*$imposition, $Equipment );
					$PunchPrice{'Total'} = $PunchPrice{'Price'} * $$specs{'txtDieCutPunches'} * $imposition;
					$DiePrice{'Price'} += $PunchPrice{'Total'};
				} # end if
#$die_price += $punch_price;
#$log->debug(" ** Adding Punch Cost: $punch_price For $$specs{'txtDieCutPunches'} Punches, MakeReady Total: $make_ready ** ");
			} # end if punches
		} # end if rule & bend 
	} #end if supplied die

	$Total{'DiePrice'} = \%DiePrice;
	if ( $$specs{'OverrideDiePrice'} eq 'Y' ) {
		$DiePrice{'Price'} = $$specs{'DiePrice'.$qty_index};
	} # end if
	$Total{'Total'} += $DiePrice{'Price'};
	$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;DiePrice: $%.2f<br/>', $DiePrice{'Price'});
#$$specs{'hdnBreakdown'.$qty_index} .= 'Materials: $' . sprintf( '%.2f', $price{'MaterialPrice'}->{'Price'})."\n";

	# Why 1.28, overs I assume
	my $impressions = $$specs{"txtQuantity$qty_index"} / $imposition * 1.28;
# this is the price for acutal die cutting, priced by impressions.
	my %ServicePrice = openprint::service::get_price_object( 'DieCutting'.$$specs{'rdbDieCutting'}, $impressions, $Equipment );
	if ( ! %ServicePrice ) {
		%ServicePrice = openprint::service::get_price_object( 'DieCutting', $impressions, $Equipment );
	} # end if

	$ServicePrice{'Total'} = $impressions * $ServicePrice{'Price'} / 1000;
	$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Service: $%.2f %s * %d impressions = $%.2f<br/>', @ServicePrice{'Price','units'}, $impressions, $ServicePrice{'Total'});
	$Total{'ServicePrice'} = \%ServicePrice;
	$Total{'Total'} += $ServicePrice{'Total'};
# the extra services are priced by qty, not impressions.
#if ( $folding eq 'Y' ) {
#my $folding_price =  openprint::service::get_price( 'HandFolding'.$die_complexity ,$qty, '') / 1000; 
#$run_price += $qty * $folding_price;
#} # end fi

	my $hole_clearing_holes = $$specs{'rdbHoleClearing'} eq 'N' ? 0 : $$specs{'txtHoleClearingHoles'};
	if ( $hole_clearing_holes > 0 ) {
		my %HoleClearingPrice = openprint::service::get_price_object( 'HoleClearing', $hole_clearing_holes * $$specs{"txtQuantity$qty_index"}, undef ); 
		$HoleClearingPrice{'Total'} = $impressions * $HoleClearingPrice{'Price'} * $hole_clearing_holes;
		if ( lc $HoleClearingPrice{'units'} eq 'per m' ) {
			$HoleClearingPrice{'Total'} /= 1000;
		} # end if
		$Total{'HoleClearingPrice'} = \%HoleClearingPrice;
		$Total{'Total'} += $HoleClearingPrice{'Total'};
	} # end if

	#if ( $$specs{'rdbGlued'} eq 'Y' ) {
		#my $gluing_price =  openprint::service::get_price( 'Gluing'.$$specs{'rdbDieCutting'}, $$specs{"txtQuantity$qty_index"}, '') / 1000; 
		#$run_price += $$specs{"txtQuantity$qty_index"} * $gluing_price;
	#} elsif ( $$specs{'rdbGlued'} eq 'M' ) {
		#my $gluing_price =  openprint::service::get_price( 'GluingMachine', $$specs{"txtQuantity$qty_index"}, '') / 1000; 
		#$run_price += $$specs{"txtQuantity$qty_index"} * $gluing_price;
	#} # end if
	#my $total_price = $make_ready + $run_price;	

	$Total{'txtPrice'} = $Total{'Total'};
	$Total{'txtUnitPrice'} = $Total{'Total'} / $$specs{"txtQuantity$qty_index"};
	$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Total: $%.2f<br/>', $Total{'txtPrice'});
    return %Total;

} # end sub calc_price

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	if ( ! $$specs{'rdbSuppliedDie'} ) {
		return 'uncalculated';
	} # end if

	if ( ( $$specs{'rdbSuppliedDie'} eq 'N' ) and ( ! $$specs{'rdbDieCutting'} ) ) {
		return 'uncalculated';
	} # end if

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();
	my $printing_specs = openprint::service::get_specs_ref( $project_index, $services{''}[0] );

	if ( ! $$specs{'rdbDieCutting'} ) {
		if ( $$printing_specs{'rdbTemplateType'} eq 'PresentationFolderStandard2Pocket' ) {
			$$specs{'rdbDieCutting'} = 'Average';
		} elsif ( $$printing_specs{'rdbTemplateType'} eq 'PresentationFolderStandard1Pocket' ) {
			$$specs{'rdbDieCutting'} = 'Simple';
		} else {
			$$specs{'rdbDieCutting'} = 'Complex';
		} # end if
	} # end if

	if ( $$specs{'chkOverrideDimensions'} ne 'Y' ) {
		@$specs{'txtDieWidth','txtDieHeight'} = @$printing_specs{'txtWidth','txtHeight'};
	} # end if

# now we have to make a custom die
	if ( $$specs{'rdbDieCutting'} eq 'Simple' ) {
		$$specs{'txtSteelRuleLength'} = 6;
	} elsif ( $$specs{'rdbDieCutting'} eq 'Average' ) {
		$$specs{'txtSteelRuleLength'} = 9;
	} elsif ( $$specs{'rdbDieCutting'} eq 'Complex' ) {
		$$specs{'txtSteelRuleLength'} = 12;
	} # end if

	if ( ! $$specs{'txtSteelRuleLength'} ) {
#or ! $$specs{'txtDieCutBends'} ) {
		$log->debug(" ** Required Data Missing for Custom Die, Rule Length: $$specs{'txtSteelRuleLength'} Bends: $$specs{'txtDieCutBends'} ** ");
		return 'uncalculated';
	} # end if
	if ( ! ( $$specs{'txtDieWidth'} or $$specs{'txtDieHeight'} ) ) {
		return 'uncalculated';
	} # end if

	my @possible_equipment = openprint::Equipment::find( 'UseInEstimating'=>'true', 'Specifications'=>{'Die Cutting Capable'=>'Y'}, 'order'=>'lower(strname)' );

    foreach my $qty_index ( 1 .. 3 ) {
		
		$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{"txtQuantity$qty_index"};
		next if ! $qty;
		$$specs{'hdnBreakdown'.$qty_index} = 'Quantity: ' . $$specs{"txtQuantity$qty_index"} . '<br/>';

		my $totalPrice = 0;
		my $totalUnitPrice = 0;
		my $totalDiePrice = 0;
        foreach my $signature_service_index ( $Project->signatures() ) {
            my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );

            @variables = sets::union( @variables,
                "txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}",
                "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index", "chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
				"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index", "chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index",
				"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index",
            );

            $$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';

			@$specs{"txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};

			my %bestPrice;
			my $bestEquipment;
			my $bestImposition;

			my @equipment;

			if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
				$log->debug("Overriding Equipment!");
				@equipment = openprint::Equipment::find('strid'=> $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} );
			} else {
				@equipment = @possible_equipment;
			} # end if

			if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
				if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > @$sig_specs{'txtImposition'.$qty_index} or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
					$$specs{'alert'} = "The specified imposition is not possible.";
					last;
				} # end if
			} # end if

			my $imposition = new openprint::Imposition();
			@$imposition{'imposition','rows','columns', 'image_orientation'} = @$sig_specs{'txtImposition'.$qty_index, 'hdnImpositionRows'.$qty_index,'hdnImpositionColumns'.$qty_index,'hdnImageOrientation'.$qty_index};

			my @impositions = ();
			if ( $services{'Cutting'} ) {
				my @imps = openprint::imposition::get_all_impositions( $imposition );
				for ( my $i = 0; $i < @imps; $i += 1 ) {
					if (
							( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' )
							or ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} == $imps[$i]->imposition() )
					   ) {
						push @impositions, $imps[$i];
					} # end if
					for ( my $j = $i + 1; $j < @imps; $j += 1 ) {
						if ( $imps[$i]->imposition() == $imps[$j]->imposition() and $imps[$i]->rows() == $imps[$j]->rows() ) {
							splice @imps, $j, 1;
							$j -= 1;
						} # end if
					} # end foreach
				} # end foreach
			} else {
				@impositions = ( $imposition );
			} # end if

			foreach my $Equipment ( @equipment ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "Equipment: ".$Equipment->strid()."<br/>";

				foreach my $imposition ( @impositions ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "&nbsp;Imposition: $$imposition{'imposition'}";
					my $width = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $$imposition{$imposition->image_orientation() eq 'Vertical' ? 'columns' : 'rows'};
					my $height = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $$imposition{$imposition->image_orientation() eq 'Vertical' ? 'rows' : 'columns'};
#$log->debug(qq` $$imposition{'Orientation'} : $$specs{"txtWidth-$printing_specs{'SignatureIndex'}"}*$$imposition{'Rows'}  x $$specs{"txtHeight-$printing_specs{'SignatureIndex'}"}*$$imposition{'Cols'} ` );
					if ( $_ = $Equipment->fits( $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
						$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit. $_<br/>";
						next;
					} # end if

					my %price = calc_price($log, $dbh, $variable, $specs, $Equipment, $qty_index, $imposition->imposition());
					if ( ! $bestPrice{'txtPrice'} or $price{'txtPrice'} < $bestPrice{'txtPrice'} ) {
						$bestEquipment = $Equipment;
						%bestPrice = %price;
						$bestImposition = $imposition;
					} # end if

				} # end foreach imposition
			} # end foreach equipment

			if ( $bestEquipment ) {
				$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestEquipment->strid();
				$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestImposition->imposition();

				if ( $bestImposition->image_orientation() eq 'Vertical' ) {
					$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $bestImposition->columns();
					$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $bestImposition->rows();
				} else {
					$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $bestImposition->rows();
					$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $bestImposition->columns();
				} # end if
				$totalPrice += $bestPrice{'txtPrice'};
				$totalUnitPrice += $bestPrice{'txtUnitPrice'};
				$totalDiePrice += $bestPrice{'DiePrice'}{'Price'} if $bestPrice{'DiePrice'};
			} # end if
		} # end foreach Signature

	
		$$specs{"DiePrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalDiePrice );
		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalPrice );
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $totalUnitPrice );

	} # end foreach qty

	return $status;
} # end sub

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;	

	my $Project = new openprint::Project( $project_index );

	@{$$variable{'EquipmentArray'}} = sql::execute( $log, $dbh, q{SELECT lngEquipmentIndex FROM tbl_Equipment_Specifications WHERE strName='Die Cutting Capable' and strValue = 'Y'} );

	if ( $$variable{'rdbTemplateTypePresentationFolderStandard1Pocket'} ne '' or $$variable{'rdbTemplateTypePresentationFolderStandard2Pocket'} ne '' ) {
		$$variable{'ShowPresentationFolderDieCutting'} = 'Y';
	} # end if

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		push @{$$variable{'SignatureGroups'}}, @$sig_specs{'SignatureIndex','txtServiceDescription'};
	} # end foreach

} # end sub display

1;
__END__
