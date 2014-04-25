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
use constant DEBUG => 1;

require openprint::Equipment;
require openprint::service;
use openprint;
use vars qw( $log $dbh );
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my @variables = (
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'OverridePrice1','OverridePrice2','OverridePrice3',
	'Markup1','Markup2','Markup3',
	'txtPrice1','txtPrice2','txtPrice3',
	'MPrice1','MPrice2','MPrice3',
	'DiePrice1','DiePrice2','DiePrice3', 
	'OverrideDiePrice1', 'OverrideDiePrice2', 'OverrideDiePrice3',
	'StrippingPrice1','StrippingPrice2','StrippingPrice3', 
	'OverrideStrippingPrice1', 'OverrideStrippingPrice2', 'OverrideStrippingPrice3',
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
		foreach my $qty_index ( $Project->quantity_indexes() ) {
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

sub outputs {
	return @output;
} # end sub get_output

my @no_outputs = (
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1','Markup2','Markup3',
	'txtQuantity1','txtQuantity2','txtQuantity3',
);

sub no_outputs {
	return @no_outputs;
}
sub calc_price {
    my ( $specs, $Equipment, $qty_index, $imposition, $sig_specs ) = @_;

	my %Total;

	my %MakeReady = openprint::service::get_price_object( 'DieCutting-'.$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}}.'MakeReady' ,undef, $Equipment );
	if ( ! %MakeReady ) {
		%MakeReady = openprint::service::get_price_object( 'DieCuttingMakeReady' ,undef, $Equipment );
	} # end if
	$Total{'MPrice'} = 0;
	$Total{'MakeReady'} = \%MakeReady;
	$Total{'Total'} += $MakeReady{'Price'};

	my %DiePrice;

	if ( $$specs{'rdbSuppliedDie-'.$$sig_specs{'SignatureIndex'}} eq 'Y' ) {
		# if customer is supplying die, then there is no die cost.
		#$log->debug(" ** Customer is Supplying Die ** ");
	} else { 
		if ( $$sig_specs{'rdbTemplateType'} ) {
# check for a standard die.
			if ( my $Material = openprint::Material->find_one('name'=>$$sig_specs{'rdbTemplateType'}.'Die') ) {
				%DiePrice = $Material->get_price( undef, $Equipment );
			} # end if
		} # end if
		if ( ( ! %DiePrice ) and $$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}} ) {
			if ( my $Material = openprint::Material->find_one('name'=>$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}}.'Die') ) {
				%DiePrice = $Material->get_price( undef, $Equipment );
			} # end if
		} # end if
			
		if ( ! %DiePrice ) {
			my %BendingPrice = openprint::service::get_price_object( 'DieCutRuleBending',$$specs{'txtDieCutBends'}*$imposition, undef );
			$BendingPrice{'Total'} = $BendingPrice{'Price'} * $$specs{'txtDieCutBends'} * $imposition;
			$DiePrice{'Price'} += $BendingPrice{'Total'};
#$die_price += $bending_price;
#$log->debug(" ** Adding Bending Cost: $bending_price For $$specs{'txtDieCutBends'} Bends, MakeReady Total: $make_ready ** ");
			if ( my $Material = openprint::Material->find_one('name'=>'DieCuttingDieRule') ) {
				my %SteelRulePrice = $Material->get_price( $$specs{'txtSteelRuleLength-'.$$sig_specs{'SignatureIndex'}}*$imposition, undef );
				$SteelRulePrice{'Total'} = $SteelRulePrice{'Price'} * $$specs{'txtSteelRuleLength-'.$$sig_specs{'SignatureIndex'}}*$imposition;
				$DiePrice{'Price'} += $SteelRulePrice{'Total'};
			} # end if
#$die_price += $steel_rule_price;
#$log->debug(" ** Adding Rule Cost: $steel_rule_price For $$specs{'txtSteelRuleLength'} Inches, MakeReady Total: $make_ready ** ");
#
			if ( $$specs{'txtDieCutPunches'} > 0 ) {
##punches are optional
				if ( my $Material = openprint::Material->find_one('name'=>'DieCutPunch'.$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}}) ) {
					my %PunchPrice = $Material->get_price( $$specs{'txtDieCutPunches-'.$$sig_specs{'SignatureIndex'}}*$imposition, $Equipment );
					$PunchPrice{'Total'} = $PunchPrice{'Price'} * $$specs{'txtDieCutPunches-'.$$sig_specs{'SignatureIndex'}} * $imposition;
					$DiePrice{'Price'} += $PunchPrice{'Total'};
				} # end if
#$die_price += $punch_price;
#$log->debug(" ** Adding Punch Cost: $punch_price For $$specs{'txtDieCutPunches'} Punches, MakeReady Total: $make_ready ** ");
			} # end if punches
		} # end if rule & bend 
	} #end if supplied die

	$Total{'DiePrice'} = \%DiePrice;
	if ( $$specs{'OverrideDiePrice'.$qty_index} eq 'Y' ) {
		$DiePrice{'Price'} = $$specs{'DiePrice'.$qty_index};
	} # end if
	$Total{'Total'} += $DiePrice{'Price'};

	# Why 1.28, overs I assume
	my $impressions = ceil($$specs{"txtQuantity$qty_index"} / $imposition);
	
	if ( my $Overs = $Equipment->Specification('DieCutting Overs') ) {
		my $overs;
		if ( $$Overs{'units'} eq 'Percent' ) {
			$overs = int( $impressions * ($$Overs{'value'}/100) );
		} elsif ( $$Overs{'units'} eq 'Sheets' ) {
			$overs = int( $$Overs{'value'} );
		} # end if
		$Total{'Overs'} = $overs;
		$impressions += $overs;
	} # end if
	$Total{'Impressions'} = $impressions;

	if ( $$specs{'OverrideStrippingPrice'.$qty_index} ne 'Y' ) {
		my %Stripping = openprint::service::get_price_object( 'DieCutting'.$$specs{'rdbDieCutting-'.$$sig_specs{'SignatureIndex'}}.'Stripping' ,undef, $Equipment );
		if ( ! %Stripping ) {
			%Stripping = openprint::service::get_price_object( 'DieCuttingStripping' ,undef, $Equipment);
		} # end if
		if ( lc $Stripping{'units'} eq 'per m' ) {
			$Stripping{'Total'} = $Stripping{'Price'} * $impressions / 1000;
		} # end if

		$Total{'Stripping'} = \%Stripping;
		$Total{'MPrice'} += $Stripping{'Price'};
		$Total{'Total'} += $Stripping{'Total'};
	} else {
		$Total{'MPrice'} += ( $$specs{"StrippingPrice$qty_index"} / $impressions ) * 1000;
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
	$Total{'MPrice'} += ( $ServicePrice{'Total'} / $impressions ) * 1000;
# the extra services are priced by qty, not impressions.
#if ( $folding eq 'Y' ) {
#my $folding_price =  openprint::service::get_price( 'HandFolding'.$die_complexity ,$qty, '') / 1000; 
#$run_price += $qty * $folding_price;
#} # end fi

	if ( $$specs{'txtHoleClearingHoles-'.$$sig_specs{'SignatureIndex'}} > 0 ) {
		my $hole_qty = $$specs{'txtHoleClearingHoles-'.$$sig_specs{SignatureIndex}} * $imposition;
		my %HoleClearingPrice = openprint::service::get_price_object( 'HoleClearing', $$specs{'txtHoleClearingHoles-'.$$sig_specs{'SignatureIndex'}} * $$specs{"txtQuantity$qty_index"}, $Equipment ); 
		$HoleClearingPrice{Total} = $impressions * $HoleClearingPrice{'Price'} * $hole_qty;
		if ( lc $HoleClearingPrice{'units'} eq 'per m' ) {
			$HoleClearingPrice{'Total'} /= 1000;
		} # end if
		$Total{'HoleClearingPrice'} = \%HoleClearingPrice;
		$Total{'Total'} += $HoleClearingPrice{'Total'};
		$Total{'MPrice'} += ( $HoleClearingPrice{'Total'} * $$specs{'txtHoleClearingHoles-'.$$sig_specs{'SignatureIndex'}} / $impressions ) * 1000;
		#$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Hole Clearing: $%.2f %s * %d impressions * %d holes = $%.2f<br/>', @HoleClearingPrice{'Price','units'}, $impressions, $hole_qty, $HoleClearingPrice{'Total'});
	} # end if

	$Total{'txtPrice'} = $Total{'Total'};
	$Total{'txtUnitPrice'} = $Total{'Total'} / $$specs{"txtQuantity$qty_index"};
    return %Total;

} # end sub calc_price

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';
	my $Project = new openprint::Project( $project_index );

	my @signatures_needing = ();

	foreach my $signature_service_index ( $Project->signatures( { sort=>1 }) ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
	
		if ( ! $$specs{"Needed-$$sig_specs{SignatureIndex}"} ) {
			if ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
				$$specs{"Needed-$$sig_specs{SignatureIndex}"} = 'Y';
			} elsif ( $Project->signatures() == 1 ) {
				$$specs{"Needed-$$sig_specs{SignatureIndex}"} = 'Y';
			} else {
				$$specs{"Needed-$$sig_specs{SignatureIndex}"} = 'N';
			} # end if
		} # end if
			
		if ( $$specs{"Needed-$$sig_specs{SignatureIndex}"} eq '' ) {
			$$specs{'alert'} .= 'Please select whether die cutting is required for signature ' . $$sig_specs{'SignatureIndex'} . '.<br/>';
			return $$specs{'Status'} = 'uncalculated';
		} elsif ( $$specs{"Needed-$$sig_specs{SignatureIndex}"} eq 'N' ) {
			next;
		} # end if
		push @signatures_needing, $signature_service_index;

		if ( exists $$specs{'rdbSuppliedDie'} and ! exists $$specs{'rdbSuppliedDie-'.$$sig_specs{'SignatureIndex'}} ) {
			$$specs{'rdbSuppliedDie-'.$$sig_specs{'SignatureIndex'}} = $$specs{'rdbSuppliedDie'};
		} # end if
		if ( ! $$specs{'rdbSuppliedDie-'.$$sig_specs{'SignatureIndex'}} ) {
			$$specs{'alert'} .= 'Please select whether the die is to be supplied by the customer or not for signature ' . $$sig_specs{'SignatureIndex'} . '.<br/>';
			return $$specs{'Status'} = 'uncalculated';
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

	foreach my $qty_index ( $Project->quantity_indexes() ) {

		$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{"txtQuantity$qty_index"};

		my $totalPrice = 0;
		my $totalUnitPrice = 0;
		my $totalMPrice = 0;
		my $totalDiePrice = 0;
		my $totalStrippingPrice = 0;

		foreach my $signature_service_index ( @signatures_needing ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			next if ! $$sig_specs{'txtImposition'.$qty_index};

			$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'} ne '';
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index );
			my %results = signature_calc( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Imposition );
			$$specs{'hdnBreakdown'.$qty_index} .= $results{'breakdown'};
			$$specs{'alert'} .= $results{'alert'};
			if ( $results{'Equipment'} ) {
				$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Equipment'}->id();
				$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Imposition'}->imposition();

				if ( $results{'Imposition'}->image_orientation() eq 'Vertical' ) {
					$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $results{'Imposition'}->columns();
					$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $results{'Imposition'}->rows();
				} else {
					$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtWidth-$$sig_specs{'SignatureIndex'}"} * $results{'Imposition'}->rows();
					$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $$specs{"txtHeight-$$sig_specs{'SignatureIndex'}"} * $results{'Imposition'}->columns();
				} # end if
				$totalPrice += $results{'Price'}{'Total'};
				$totalUnitPrice += $results{'Price'}{'txtUnitPrice'};
				$totalMPrice += $results{'Price'}{'MPrice'};
				$totalDiePrice += $results{'Price'}{'DiePrice'}{'Price'} if $results{'Price'}{'DiePrice'};
				$totalStrippingPrice += $results{'Price'}{'Stripping'}{'Total'} if $results{'Price'}{'Stripping'};

				$$specs{'hdnBreakdown'.$qty_index} .= 'Equipment: '.$results{'Equipment'}->strid().'<br/>';
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;MakeReady: $%.2f<br/>', $results{'Price'}{'MakeReady'}{'Price'});
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;DiePrice: $%.2f<br/>', $results{'Price'}{'DiePrice'}{'Price'});
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Service: $%1$.2f%2$s * %4$d impressions = $%3$.2f<br/>', @{$results{'Price'}{'ServicePrice'}}{'Price','units','Total'}, $results{'Price'}{'Impressions'} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Hole Clearing: $%1$.2f%2$s * %5$d holes * %6$dout * %4$d impressions = $%3$.2f<br/>', @{$results{'Price'}{'HoleClearingPrice'}}{'Price','units','Total'}, $results{'Price'}{'Impressions'}, $$specs{"txtHoleClearingHoles-$$sig_specs{'SignatureIndex'}"}, $results{Imposition}->imposition() ) if exists $results{'Price'}{'HoleClearingPrice'};

				if ( $$specs{'OverrideStrippingPrice'.$qty_index} ne 'Y' ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Stripping: $%1$.2f%2$s * %4$d impressions = $%3$.2f<br/>', @{$results{'Price'}{'Stripping'}}{'Price','units','Total'}, $results{'Price'}{'Impressions'} );
					@no_outputs = sets::exclude( ["StrippingPrice$qty_index"], \@no_outputs );
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Stripping: $%1$.2f<br/>', $$specs{"StrippingPrice$qty_index"} );
					@no_outputs = sets::union( @no_outputs, "StrippingPrice$qty_index" );
				} # end if

				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Total: $%.2f * %s% = $%.2f<br/>', $results{'Price'}{'txtPrice'},$$specs{'Markup'.$qty_index}, $totalPrice*(1+$$specs{'Markup'.$qty_index}/100));
			} # end if
		} # end foreach Signature
	
		if ( $$specs{'OverrideDiePrice'.$qty_index} ne 'Y' ) {
			$$specs{"DiePrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalDiePrice );
		} # end if
		if ( $$specs{'OverrideStrippingPrice'.$qty_index} ne 'Y' ) {
			$$specs{"StrippingPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalStrippingPrice );
		} else {
			$$specs{"StrippingPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"StrippingPrice$qty_index"} );
		} # end if
		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalPrice*(1+$$specs{'Markup'.$qty_index}/100)*(1+$Project->markup()/100) );
			@no_outputs = sets::exclude( ["txtPrice$qty_index"], \@no_outputs );
		} else {
			@no_outputs = sets::union( "txtPrice$qty_index", @no_outputs );
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, ($totalUnitPrice*(1+$Project->markup()/100)) );
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $totalMPrice*(1+$$specs{'Markup'.$qty_index}/100)*(1+$Project->markup()/100) );

	} # end foreach qty

	return $status;
} # end sub calc

sub signature_needs {
	my ( $Project, $specs, $sig_specs ) = @_;
#$log->debug("Diecutting::signatureNeeds: for sig $$sig_specs{SignatureIndex} : Needed: ($$specs{'Needed-'.$$sig_specs{SignatureIndex}})" );
	if ( ! $$specs{"Needed-$$sig_specs{SignatureIndex}"} ) {
		if ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
			return 1;
		} # end if
		my $ServiceType = openprint::ServiceType->find_one('type'=>'DieCutting');
		if ( $ServiceType ) {
			if ( sets::isin( $ServiceType->id(), [ $Project->Type()->required_services() ] ) ) {
				return 1;
			} # end if
		} else {
			$openprint::log->error("No ServiceType for DieCutting");
		}
	} # end if
	return $$specs{"Needed-$$sig_specs{SignatureIndex}"} eq 'Y' ? 1 : 0;
} # end sub signature_needs

sub signature_calc {
	my ( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Imposition ) = @_;

	@$specs{"txtWidth-$$sig_specs{'SignatureIndex'}", "txtHeight-$$sig_specs{'SignatureIndex'}"} = @$sig_specs{'txtWidth','txtHeight'};

	my %results;

	my @equipment;
	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		$log->debug("Overriding Equipment!");
		@equipment = ( new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) );
	} else {
		@equipment = openprint::Equipment->find( useinestimating=>1, Specifications=>{'Die Cutting Capable'=>'Y'} );
	} # end if

	if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > @$sig_specs{'txtImposition'.$qty_index} or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
			$results{'alert'} = 'The specified imposition is not possible.';
			last;
		} # end if
	} # end if

	my @impositions = ();
	my $services = $Project->services();
	if ( $$services{'Cutting'} ) {
		my @imps = openprint::imposition::get_all_impositions( $Imposition );
$log->debug("# of imps to consider: " . @imps ) if DEBUG;
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
		@impositions = ( $Imposition );
	} # end if

	foreach my $Equipment ( @equipment ) {
		if ( ( $$specs{'txtHoleClearingHoles'} > 0 ) and ( $Equipment->specification('HoleClearing Capable') ne 'Y') ) {
			next;
		} # end if

		foreach my $imposition ( @impositions ) {
			my $width = $imposition->layout_width();
			my $height = $imposition->layout_height();
			if ( $_ = $Equipment->fits( $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
				if ( 1 == @equipment ) {
					$results{'breakdown'} .= "Doesn't fit. $_<br/>";
				} # end if
				next;
			} # end if

			my %price = calc_price( $specs, $Equipment, $qty_index, $imposition->imposition(), $sig_specs );
			if ( ! $results{'Price'} or $price{'txtPrice'} < $results{'Price'}{'txtPrice'} ) {
				$results{'Equipment'} = $Equipment;
				%{$results{'Price'}} = %price;
				$results{'Imposition'} = $imposition;
				$results{'Overs'} = $price{'Overs'};
			} # end if

		} # end foreach imposition
	} # end foreach equipment
	return %results;
} # end sub signature_calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;	

	@{$$variable{'Equipment'}} = openprint::Equipment->find(order=>'lower(strname)', 'useinestimating'=>1,'Specifications'=>{'Die Cutting Capable'=>'Y'} );

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
		my $summary;
		my $Owner = new openprint::Company( $openprint::config{owner_id} );
		my @signatures = $Project->signatures();

		foreach my $signature ( @signatures ) {
			my $Service = $Project->Service($signature);
			my $sig_specs = $Service->specs();

			if ( $$specs{'rdbSuppliedDie-'.$$sig_specs{SignatureIndex}} eq 'Y' ) {
				$summary .= 'Customer supplies die' . ( @signatures > 1 ? ' for form '.$$sig_specs{SignatureIndex} : '' ).'<br/>';
			} else {
				$summary .= $Owner->name() . ' supplies die'.( @signatures > 1 ? ' for form '.$$sig_specs{SignatureIndex} : '' ).'<br/>';
			} # end if
		} # end foreach
		return $summary;
	} # end if

	return '';
} # end sub summary

sub save {
} # end sub save

1;
__END__
