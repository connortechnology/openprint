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
use POSIX qw( ceil );

require openprint::project;
require openprint::Equipment;
require openprint::service;
require openprint::print;

require sql;

my @variables = (
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'OverridePrice1','OverridePrice2','OverridePrice3',
	'Markup1','Markup2','Markup3',
	'txtPrice1','txtPrice2','txtPrice3',
	'DiePrice1','DiePrice2','DiePrice3', 'OverrideDiePrice',
	'StrippingPrice1','StrippingPrice2','StrippingPrice3', 'OverrideStrippingPrice',
);

sub variables {
	my ( $p_id, $s_id, $specs ) = @_;

	my @v = @variables;
	my $Project = new openprint::Project( $p_id );
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		push @v, ("txtWidth-$$sig_specs{'SignatureIndex'}","txtHeight-$$sig_specs{'SignatureIndex'}",
			 "rdbDieCutting-$$sig_specs{'SignatureIndex'}","Needed-$$sig_specs{SignatureIndex}",
			 "rdbSuppliedDie-$$sig_specs{'SignatureIndex'}","txtDieCutPunches-$$sig_specs{'SignatureIndex'}",
			 "txtSteelRuleLength-$$sig_specs{'SignatureIndex'}","txtDieCutBends-$$sig_specs{'SignatureIndex'}","txtHoleClearingHoles-$$sig_specs{'SignatureIndex'}");
		foreach my $qty_index ( 1 .. 3 ) {
			next if ! $Project->quantity( $qty_index );
			push @v,(
				 "ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index", "chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
				 "txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index", "chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index",
				 "txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index",
				 );
		} # end foreach qty_index
	} # end foreach signatures
	return @v;
} # end sub variables

my @output = (
		);

sub get_output {
	return @output;
} # end sub get_output

sub calc_price {
    my ( $log, $dbh, $variable, $specs, $Equipment, $qty_index, $imposition, $sig_specs ) = @_;

	my %Total;

	my %MakeReady = openprint::service::get_price_object( 'DieCutting-'.$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}}.'MakeReady' ,undef, $Equipment );
	if ( ! %MakeReady ) {
		%MakeReady = openprint::service::get_price_object( 'DieCuttingMakeReady' ,undef, $Equipment );
	} # end if
	$Total{'MakeReady'} = \%MakeReady;
	$Total{'Total'} += $MakeReady{'Price'};

	my %DiePrice;
	if ( $$specs{'rdbSuppliedDie-'.$$sig_specs{'SignatureIndex'}} eq 'Y' ) {
		# if customer is supplying die, then there is no die cost.
		$log->debug(" ** Customer is Supplying Die ** ");
	} else { 
		if ( $$sig_specs{'rdbTemplateType'} ) {
# check for a standard die.
			if ( my @Materials = openprint::Material::find('name'=>$$sig_specs{'rdbTemplateType'}.'Die') ) {
				%DiePrice = $Materials[0]->get_price( undef, $Equipment );
			} # end if
		} # end if
		if ( ( ! %DiePrice ) and $$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}} ) {
			if ( my @Materials = openprint::Material::find('name'=>$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}}.'Die') ) {
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
				my %SteelRulePrice = $Materials[0]->get_price( $$specs{'txtSteelRuleLength-'.$$sig_specs{'SignatureIndex'}}*$imposition, undef );
				$SteelRulePrice{'Total'} = $SteelRulePrice{'Price'} * $$specs{'txtSteelRuleLength-'.$$sig_specs{'SignatureIndex'}}*$imposition;
				$DiePrice{'Price'} += $SteelRulePrice{'Total'};
			} # end if
#$die_price += $steel_rule_price;
#$log->debug(" ** Adding Rule Cost: $steel_rule_price For $$specs{'txtSteelRuleLength'} Inches, MakeReady Total: $make_ready ** ");
#
			if ( $$specs{'txtDieCutPunches'} > 0 ) {
##punches are optional
				if ( my @Materials = openprint::Material::find('name'=>'DieCutPunch'.$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}}) ) {
					my %PunchPrice = $Materials[0]->get_price( $$specs{'txtDieCutPunches-'.$$sig_specs{'SignatureIndex'}}*$imposition, $Equipment );
					$PunchPrice{'Total'} = $PunchPrice{'Price'} * $$specs{'txtDieCutPunches-'.$$sig_specs{'SignatureIndex'}} * $imposition;
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

	# Why 1.28, overs I assume
	my $impressions = ceil($$specs{"txtQuantity$qty_index"} / $imposition);
	$Total{'Impressions'} = $impressions;

	if ( $$specs{'OverrideStrippingPrice'} ne 'Y' ) {
		my %Stripping = openprint::service::get_price_object( 'DieCutting'.$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}}.'Stripping' ,undef, $Equipment );
		if ( ! %Stripping ) {
			%Stripping = openprint::service::get_price_object( 'DieCuttingStripping' ,undef, $Equipment);
		} # end if
		if ( lc $Stripping{'units'} eq 'per m' ) {
			$Stripping{'Total'} = $Stripping{'Price'} * $impressions / 1000;
		} # end if

		$Total{'Stripping'} = \%Stripping;
		$Total{'Total'} += $Stripping{'Total'};
	} else {
		$Total{'Total'} += $$specs{"StrippingPrice$qty_index"};
	} # end if

#$$specs{'hdnBreakdown'.$qty_index} .= 'Materials: $' . sprintf( '%.2f', $price{'MaterialPrice'}->{'Price'})."\n";

# this is the price for actual die cutting, priced by impressions.
	my %ServicePrice = openprint::service::get_price_object( 'DieCutting'.$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}}, $impressions, $Equipment );
	if ( ! %ServicePrice ) {
		%ServicePrice = openprint::service::get_price_object( 'DieCutting', $impressions, $Equipment );
	} # end if

	$ServicePrice{'Total'} = $impressions * $ServicePrice{'Price'} / 1000;
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

	$Total{'txtPrice'} = $Total{'Total'};
	$Total{'txtUnitPrice'} = $Total{'Total'} / $$specs{"txtQuantity$qty_index"};
    return %Total;

} # end sub calc_price

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';
	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
	
		if ( ! $$specs{"Needed-$$sig_specs{SignatureIndex}"} ) {
			$$specs{"Needed-$$sig_specs{SignatureIndex}"} = 'N';
			if ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
				$$specs{"Needed-$$sig_specs{SignatureIndex}"} = 'Y';
			} # end if
		} # end if
			
		if ( $$specs{"Needed-$$sig_specs{SignatureIndex}"} ne 'Y' ) {
			next;
		} # end if

		if ( ! $$specs{'rdbSuppliedDie-'.$$sig_specs{'SignatureIndex'}} ) {
			$$specs{'alert'} .= 'Please select whether the die is to be supplied by the customer or not for signature ' . $$sig_specs{'SignatureIndex'} . '.<br/>';
			return 'uncalculated';
		} # end if
		if ( ! $$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}} ) {
			if ( $$sig_specs{'rdbTemplateType'} eq '2Panel2Pocket' ) {
				$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}} = 'Average';
			} elsif ( $$sig_specs{'rdbTemplateType'} eq '2Panel1Pocket' ) {
				$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}} = 'Simple';
			} else {
				$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}} = 'Complex';
			} # end if
		} # end if
		if ( ( $$specs{'rdbSuppliedDie-'.$$sig_specs{'SignatureIndex'}} eq 'N' ) and ( ! $$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}} ) ) {
			$$specs{'alert'} .= 'Please select the complexity of the die.<br/>';
			return 'uncalculated';
		} # end if
		if ( $$specs{'chkOverrideDimensions-'.$$sig_specs{'SignatureIndex'}} ne 'Y' ) {
			@$specs{"txtDieWidth-$$sig_specs{'SignatureIndex'}","txtDieHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};
		} # end if
		if ( ! ( $$specs{'txtDieWidth-'.$$sig_specs{'SignatureIndex'}} or $$specs{'txtDieHeight-'.$$sig_specs{'SignatureIndex'}} ) ) {
			$$specs{'alert'} .= 'Please enter the die dimensions.<br/>';
			return 'uncalculated';
		} # end if
# now we have to make a custom die
		if ( $$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}} eq 'Simple' ) {
			$$specs{'txtSteelRuleLength-'.$$sig_specs{'SignatureIndex'}} = 6;
		} elsif ( $$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}} eq 'Average' ) {
			$$specs{'txtSteelRuleLength-'.$$sig_specs{'SignatureIndex'}} = 9;
		} elsif ( $$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}} eq 'Complex' ) {
			$$specs{'txtSteelRuleLength-'.$$sig_specs{'SignatureIndex'}} = 12;
		} # end if

		if ( ! $$specs{'txtSteelRuleLength-'.$$sig_specs{'SignatureIndex'}} ) {
			$log->debug(" ** Required Data Missing for Custom Die, Rule Length: $$specs{'txtSteelRuleLength-'.$$sig_specs{'SignatureIndex'}} Bends: $$specs{'txtDieCutBends-'.$$sig_specs{'SignatureIndex'}} ** ");
			return 'uncalculated';
		} # end if
	} # end foreach signature

	my @possible_equipment = openprint::Equipment::find( 'use_in_estimating'=>1, 'Specifications'=>{'Die Cutting Capable'=>'Y'} );
	foreach my $qty_index ( 1 .. 3 ) {

		$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{"txtQuantity$qty_index"};
		next if ! $qty;

		my $totalPrice = 0;
		my $totalUnitPrice = 0;
		my $totalDiePrice = 0;
		my $totalStrippingPrice = 0;

		foreach my $signature_service_index ( $Project->signatures() ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			if ( $$specs{"Needed-$$sig_specs{SignatureIndex}"} ne 'Y' ) {
				next;
			} # end if

			$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';
			@$specs{"txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};

			my %bestPrice;
			my $bestEquipment;
			my $bestImposition;

			my @equipment;

			if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
				$log->debug("Overriding Equipment!");
				@equipment = ( new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) );
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
			if ( $$services{'Cutting'} ) {
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

				foreach my $imposition ( @impositions ) {
					my $width = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $$imposition{$imposition->image_orientation() eq 'Vertical' ? 'columns' : 'rows'};
					my $height = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $$imposition{$imposition->image_orientation() eq 'Vertical' ? 'rows' : 'columns'};
					if ( $_ = $Equipment->fits( $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
						if ( 1 == @equipment ) {
							$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit. $_<br/>";
						} # end if
						next;
					} # end if

					my %price = calc_price($log, $dbh, $variable, $specs, $Equipment, $qty_index, $imposition->imposition(), $sig_specs );
					if ( ! $bestPrice{'txtPrice'} or $price{'txtPrice'} < $bestPrice{'txtPrice'} ) {
						$bestEquipment = $Equipment;
						%bestPrice = %price;
						$bestImposition = $imposition;
					} # end if

				} # end foreach imposition
			} # end foreach equipment

			if ( $bestEquipment ) {
				$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $bestEquipment->id();
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
				$totalStrippingPrice += $bestPrice{'Stripping'}{'Total'} if $bestPrice{'Stripping'};

				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;MakeReady: $%.2f<br/>', $bestPrice{'MakeReadyPrice'}{'Price'});
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;DiePrice: $%.2f<br/>', $bestPrice{'DiePrice'}{'Price'});
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Service: $%1$.2f%2$s * %4$d impressions = $%3$.2f<br/>', @{$bestPrice{'ServicePrice'}}{'Price','units','Total'}, $bestPrice{'Impressions'} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Hole Clearing: $%1$.2f%2$s * %5$d holes * %4$d impressions = $%3$.2f<br/>', @{$bestPrice{'HoleClearingPrice'}}{'Price','units','Total'}, $bestPrice{'Impressions'}, $$specs{"txtHoleClearingHoles-$$sig_specs{'SignatureIndex'}"} ) if $bestPrice{'HoleClearingPrice'};

				if ( $$specs{'OverrideStrippingPrice'} ne 'Y' ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Stripping: $%1$.2f%2$s * %4$d impressions = $%3$.2f<br/>', @{$bestPrice{'Stripping'}}{'Price','units','Total'}, $bestPrice{'Impressions'} );
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Stripping: $%1$.2f<br/>', $$specs{"StrippingPrice$qty_index"} );
				} # end if

				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Total: $%.2f * %s% = $%.2f<br/>', $bestPrice{'txtPrice'},$$specs{'Markup'.$qty_index}, $totalPrice*(1+$$specs{'Markup'.$qty_index}/100));
			} # end if
		} # end foreach Signature

	
		$$specs{"DiePrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalDiePrice );
		if ( $$specs{'OverrideStrippingPrice'} ne 'Y' ) {
			$$specs{"StrippingPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalStrippingPrice );
		} else {
			$$specs{"StrippingPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"StrippingPrice$qty_index"} );
		} # end if
		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalPrice*(1+$$specs{'Markup'.$qty_index}/100) );
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $totalUnitPrice );

	} # end foreach qty

	return $status;
} # end sub

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;	

	@{$$variable{'Equipment'}} = openprint::Equipment::find('order'=>'lower(strname)', 'use_in_estimating'=>1,'Specifications'=>{'Die Cutting Capable'=>'Y'} );

	if ( $$variable{'rdbTemplateTypePresentationFolderStandard1Pocket'} ne '' or $$variable{'rdbTemplateTypePresentationFolderStandard2Pocket'} ne '' ) {
		$$variable{'ShowPresentationFolderDieCutting'} = 'Y';
	} # end if

} # end sub display
sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	#$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
	if ( $qty_index ) {
			return '';
	} else {
		if ( $$specs{'rdbSuppliedDie'} eq 'Y' ) {
			return 'Customer supplied die';
		} else {
			return '';
		} # end if
	} # end if

} # end sub summary

1;
__END__
