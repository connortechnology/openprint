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
#use warnings;
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
	'alert',
);

sub variables {
	my ( $p_id, $s_id, $specs ) = @_;

	my @v = @variables;
	my $Project = new openprint::Project( $p_id );
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		my $form = $$sig_specs{SignatureIndex};
		push @v, ("txtWidth-$form","txtHeight-$form",
			 "rdbDieCutting-$form","Needed-$form",
			 "rdbSuppliedDie-$form","txtDieCutPunches-$form",
			 "txtSteelRuleLength-$form","txtDieCutBends-$form","txtHoleClearingHoles-$form");
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v,(
				 "ddmEquipment-$form-$qty_index", "chkOverrideEquipment-$form-$qty_index",
				 "txtImposition-$form-$qty_index", "chkOverrideImposition-$form-$qty_index",
				 "txtLayoutWidth-$form-$qty_index", "txtLayoutHeight-$form-$qty_index",
				 );
			foreach my $imp_index ( 1 .. 4 ) {
				push @v, map { join('-', $_, $form, $qty_index, $imp_index ) } ( 'ImpOut','ImpColumns','ImpRows','ImpQty' );
			} # end foreach imp_index
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
    my ( $specs, $Equipment, $qty_index, $Imposition, $sig_specs, $Signature_Imposition ) = @_;

	my %Total = ( Imposition => $Imposition );
	my $form = $$sig_specs{SignatureIndex};

	my %MakeReady = openprint::service::get_price_object( 'DieCutting-'.$$specs{'rdbDieCutting-'.$form}.'MakeReady' ,undef, $Equipment );
	if ( ! %MakeReady ) {
		%MakeReady = openprint::service::get_price_object( 'DieCuttingMakeReady' ,undef, $Equipment );
	} # end if
	$Total{'MPrice'} = 0;
	$Total{'MakeReady'} = \%MakeReady;
	$Total{Total} += $MakeReady{'Price'};

	my %DiePrice;

	if ( $$specs{'rdbSuppliedDie-'.$form} eq 'Y' ) {
		# if customer is supplying die, then there is no die cost.
		#$log->debug(" ** Customer is Supplying Die ** ");
	} else { 
		if ( $$sig_specs{'rdbTemplateType'} ) {
# check for a standard die.
			if ( my $Material = openprint::Material->find_one( name =>$$sig_specs{rdbTemplateType}.'Die') ) {
				%DiePrice = $Material->get_price( undef, $Equipment );
			} # end if
		} # end if
		if ( ( ! %DiePrice ) and $$specs{'rdbDieCutting-'.$form} ) {
			if ( my $Material = openprint::Material->find_one( name=>$$specs{'rdbDieCutting-'.$form}.'Die') ) {
				%DiePrice = $Material->get_price( undef, $Equipment );
			} # end if
		} # end if
			
		if ( ! %DiePrice ) {
			my %BendingPrice = openprint::service::get_price_object( 'DieCutRuleBending',$$specs{'txtDieCutBends'}*$$Imposition{imposition}, undef );
			$BendingPrice{Total} = $BendingPrice{Price} * $$specs{txtDieCutBends} * $$Imposition{imposition};
			$DiePrice{Price} += $BendingPrice{Total};
#$die_price += $bending_price;
#$log->debug(" ** Adding Bending Cost: $bending_price For $$specs{'txtDieCutBends'} Bends, MakeReady Total: $make_ready ** ");
			if ( my $Material = openprint::Material->find_one('name'=>'DieCuttingDieRule') ) {
				my %SteelRulePrice = $Material->get_price( $$specs{'txtSteelRuleLength-'.$form}*$$Imposition{imposition}, undef );
				$SteelRulePrice{'Total'} = $SteelRulePrice{'Price'} * $$specs{'txtSteelRuleLength-'.$form}*$$Imposition{imposition};
				$DiePrice{'Price'} += $SteelRulePrice{'Total'};
			} # end if
#$die_price += $steel_rule_price;
#$log->debug(" ** Adding Rule Cost: $steel_rule_price For $$specs{'txtSteelRuleLength'} Inches, MakeReady Total: $make_ready ** ");
#
			if ( $$specs{'txtDieCutPunches'} > 0 ) {
##punches are optional
				if ( my $Material = openprint::Material->find_one('name'=>'DieCutPunch'.$$specs{'rdbDieCutting-'.$form}) ) {
					my %PunchPrice = $Material->get_price( $$specs{'txtDieCutPunches-'.$form}*$$Imposition{imposition}, $Equipment );
					$PunchPrice{'Total'} = $PunchPrice{'Price'} * $$specs{'txtDieCutPunches-'.$form} * $$Imposition{imposition};
					$DiePrice{'Price'} += $PunchPrice{'Total'};
				} # end if
#$die_price += $punch_price;
#$log->debug(" ** Adding Punch Cost: $punch_price For $$specs{'txtDieCutPunches'} Punches, MakeReady Total: $make_ready ** ");
			} # end if punches
		} # end if rule & bend 
	} #end if supplied die

	$Total{DiePrice} = \%DiePrice;
	if ( (defined $$specs{'OverrideDiePrice'.$qty_index}) and ( $$specs{'OverrideDiePrice'.$qty_index} eq 'Y' ) ) {
		$DiePrice{'Price'} = $$specs{'DiePrice'.$qty_index};
	} # end if
	$Total{Total} += $DiePrice{Price} if $DiePrice{Price};

	# Why 1.28, overs I assume
	my $impressions = ceil( ( $$specs{"txtQuantity$qty_index"} / $$Signature_Imposition{imposition} ) ) * $Imposition->quantity();
# * $$Imposition{imposition});
	
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

	if ( ( ! defined $$specs{'OverrideStrippingPrice'.$qty_index} ) or ( $$specs{'OverrideStrippingPrice'.$qty_index} ne 'Y' ) ) {
		my %Stripping = openprint::service::get_price_object( 'DieCutting'.$$specs{'rdbDieCutting-'.$form}.'Stripping' ,undef, $Equipment );
		if ( ! %Stripping ) {
			%Stripping = openprint::service::get_price_object( 'DieCuttingStripping' ,undef, $Equipment);
		} # end if
		if ( %Stripping ) {
			if ( lc $Stripping{'units'} eq 'per m' ) {
				$Stripping{'Total'} = $Stripping{'Price'} * $impressions / 1000;
			} # end if

			$Total{'Stripping'} = \%Stripping;
			$Total{'MPrice'} += $Stripping{'Price'};
			$Total{'Total'} += $Stripping{'Total'};
		} # end if
	} else {
		$Total{'MPrice'} += ( $$specs{"StrippingPrice$qty_index"} / $impressions ) * 1000;
		$Total{'Total'} += $$specs{"StrippingPrice$qty_index"};
	} # end if

#$$specs{'hdnBreakdown'.$qty_index} .= 'Materials: $' . sprintf( '%.2f', $price{'MaterialPrice'}->{'Price'})."\n";

# this is the price for actual die cutting, priced by impressions.
	my %ServicePrice = openprint::service::get_price_object( 'DieCutting'.$$specs{'rdbDieCutting-'.$form}, $impressions, $Equipment );
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

	if ( ( defined $$specs{'txtHoleClearingHoles-'.$form} ) and ( $$specs{'txtHoleClearingHoles-'.$form} > 0 ) ) {
		my $hole_qty = $$specs{'txtHoleClearingHoles-'.$form} * $$Imposition{imposition};
		my %HoleClearingPrice = openprint::service::get_price_object( 'HoleClearing', $$specs{'txtHoleClearingHoles-'.$form} * $$specs{"txtQuantity$qty_index"}, $Equipment ); 
		$HoleClearingPrice{Total} = $impressions * $HoleClearingPrice{'Price'} * $hole_qty;
		if ( lc $HoleClearingPrice{'units'} eq 'per m' ) {
			$HoleClearingPrice{'Total'} /= 1000;
		} # end if
		$Total{'HoleClearingPrice'} = \%HoleClearingPrice;
		$Total{'Total'} += $HoleClearingPrice{'Total'};
		$Total{'MPrice'} += ( $HoleClearingPrice{'Total'} * $$specs{'txtHoleClearingHoles-'.$form} / $impressions ) * 1000;
		#$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Hole Clearing: $%.2f %s * %d impressions * %d holes = $%.2f<br/>', @HoleClearingPrice{'Price','units'}, $impressions, $hole_qty, $HoleClearingPrice{'Total'});
	} # end if

	$Total{UnitPrice} = $Total{'Total'} / $$specs{"txtQuantity$qty_index"};
    return %Total;

} # end sub calc_price

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';
	my $Project = new openprint::Project( $project_index );

	my @signatures_needing = ();

	foreach my $signature_service_index ( $Project->signatures( { sort=>1 }) ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
		my $form = $$sig_specs{SignatureIndex};
	
		if ( ! $$specs{"Needed-$form"} ) {
			if ( sets::isin( $$sig_specs{'rdbTemplateType'}, ['2Panel1Pocket','2Panel2Pocket','TriFoldDoublePocket'] ) ) {
				$$specs{"Needed-$form"} = 'Y';
			} elsif ( $Project->signatures() == 1 ) {
				$$specs{"Needed-$form"} = 'Y';
			} else {
				$$specs{"Needed-$form"} = 'N';
			} # end if
		} # end if
			
		if ( $$specs{"Needed-$form"} eq '' ) {
			$$specs{'alert'} .= 'Please select whether die cutting is required for signature ' . $form . '.<br/>';
			return $$specs{'Status'} = 'uncalculated';
		} elsif ( $$specs{"Needed-$form"} eq 'N' ) {
			next;
		} # end if
		push @signatures_needing, $signature_service_index;

		if ( exists $$specs{'rdbSuppliedDie'} and ! exists $$specs{'rdbSuppliedDie-'.$form} ) {
			$$specs{'rdbSuppliedDie-'.$form} = $$specs{'rdbSuppliedDie'};
		} # end if
		if ( ! $$specs{'rdbSuppliedDie-'.$form} ) {
			$$specs{'alert'} .= 'Please select whether the die is to be supplied by the customer or not for signature ' . $form . '.<br/>';
			return $$specs{'Status'} = 'uncalculated';
		} # end if
		if ( ! $$specs{'rdbDieCutting-'.$form} ) {
			if ( $$sig_specs{'rdbTemplateType'} eq '2Panel2Pocket' ) {
				$$specs{'rdbDieCutting-'.$form} = 'Average';
			} elsif ( $$sig_specs{'rdbTemplateType'} eq '2Panel1Pocket' ) {
				$$specs{'rdbDieCutting-'.$form} = 'Simple';
			} else {
				$$specs{'rdbDieCutting-'.$form} = 'Complex';
			} # end if
		} # end if
		if ( ( $$specs{'rdbSuppliedDie-'.$form} eq 'N' ) and ( ! $$specs{'rdbDieCutting-'.$form} ) ) {
			$$specs{'alert'} .= 'Please select the complexity of the die.<br/>';
			return 'uncalculated';
		} # end if
		if ( (!defined $$specs{'chkOverrideDimensions-'.$form}) or ( $$specs{'chkOverrideDimensions-'.$form} ne 'Y' ) ) {
			@$specs{"txtDieWidth-$form","txtDieHeight-$form"} = @$sig_specs{'txtWidth','txtHeight'};
		} # end if
		if ( ! ( $$specs{'txtDieWidth-'.$form} or $$specs{'txtDieHeight-'.$form} ) ) {
			$$specs{'alert'} .= 'Please enter the die dimensions.<br/>';
			return 'uncalculated';
		} # end if
# now we have to make a custom die
		if ( $$specs{'rdbDieCutting-'.$form} eq 'Simple' ) {
			$$specs{'txtSteelRuleLength-'.$form} = 6;
		} elsif ( $$specs{'rdbDieCutting-'.$form} eq 'Average' ) {
			$$specs{'txtSteelRuleLength-'.$form} = 9;
		} elsif ( $$specs{'rdbDieCutting-'.$form} eq 'Complex' ) {
			$$specs{'txtSteelRuleLength-'.$form} = 12;
		} # end if

		if ( ! $$specs{'txtSteelRuleLength-'.$form} ) {
			$log->debug(" ** Required Data Missing for Custom Die, Rule Length: $$specs{'txtSteelRuleLength-'.$form} Bends: $$specs{'txtDieCutBends-'.$form} ** ");
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
			my $form = $$sig_specs{SignatureIndex};

			$$specs{'hdnBreakdown'.$qty_index} .= "Signature: $$sig_specs{'txtServiceDescription'}, " if $$sig_specs{'txtServiceDescription'};
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index );
			my %results = signature_calc( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Imposition );
			$$specs{'hdnBreakdown'.$qty_index} .= $results{breakdown} if $results{breakdown};
			$$specs{alert} .= $results{alert} if $results{alert};
			if ( $results{'Equipment'} ) {
				$$specs{"ddmEquipment-$form-$qty_index"} = $results{'Equipment'}->id();
				$$specs{'hdnBreakdown'.$qty_index} .= 'Equipment: '.$results{'Equipment'}->strid().'<br/>';
				#$$specs{"txtImposition-$form-$qty_index"} = $results{'Imposition'}->imposition();
				my $imp_index = 1;
				foreach my $Price ( @{$results{Prices}} ) {
					my $I = $$Price{Imposition};

					$$specs{'hdnBreakdown'.$qty_index} .= $I->to_string() . '<br/>';
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;MakeReady: $%.2f<br/>', $$Price{'MakeReady'}{'Price'});
					if ( $$Price{DiePrice} ) {
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;DiePrice: $%.2f<br/>', $$Price{'DiePrice'}{'Price'});
						$totalDiePrice += $Price->{DiePrice}{Price};
					} # end if
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Service: $%1$.2f%2$s * %4$d impressions = $%3$.2f<br/>', @{$$Price{'ServicePrice'}}{'Price','units','Total'}, $$Price{'Impressions'} );
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Hole Clearing: $%1$.2f%2$s * %5$d holes * %6$dout * %4$d impressions = $%3$.2f<br/>', @{$$Price{'HoleClearingPrice'}}{'Price','units','Total'}, $$Price{'Impressions'}, $$specs{"txtHoleClearingHoles-$form"}, $I->imposition() ) if exists $$Price{'HoleClearingPrice'};
					$totalUnitPrice += $Price->{UnitPrice};
					$totalMPrice += $Price->{MPrice};
					$totalStrippingPrice += $Price->{Stripping}{Total} if $Price->{Stripping};

					@$specs{
						"ImpQty-$form-$qty_index-$imp_index",
						"ImpOut-$form-$qty_index-$imp_index",
						"ImpColumns-$form-$qty_index-$imp_index",
						"ImpRows-$form-$qty_index-$imp_index"} =
						$I->get('quantity','imposition','columns','rows');
					$imp_index += 1;
				} # end foreach Imposition
				foreach $imp_index ( $imp_index .. 4 ) {
					@$specs{
						"ImpQty-$form-$qty_index-$imp_index",
						"ImpOut-$form-$qty_index-$imp_index",
						"ImpColumns-$form-$qty_index-$imp_index",
						"ImpRows-$form-$qty_index-$imp_index"} = ('','','','');
				} # end foreach $imp_index

				$totalPrice += $results{Total};

				if ( (! defined $$specs{'OverrideStrippingPrice'.$qty_index}) or ( $$specs{'OverrideStrippingPrice'.$qty_index} ne 'Y' ) ) {
					if ( $results{'Price'}{'Stripping'} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Stripping: $%1$.2f%2$s * %4$d impressions = $%3$.2f<br/>', @{$results{'Price'}{'Stripping'}}{'Price','units','Total'}, $results{'Price'}{'Impressions'} );
					} # end if
					@no_outputs = sets::exclude( ["StrippingPrice$qty_index"], \@no_outputs );
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Stripping: $%1$.2f<br/>', $$specs{"StrippingPrice$qty_index"} );
					@no_outputs = sets::union( @no_outputs, "StrippingPrice$qty_index" );
				} # end if

				if ( $$specs{'Markup'.$qty_index} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Total: $%.2f * %s%% = $%.2f<br/>', $results{Total},$$specs{'Markup'.$qty_index}, $totalPrice*(1+$$specs{'Markup'.$qty_index}/100));
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('&nbsp;&nbsp;Total: $%.2f<br/>', $results{Total} );
				} # end if
			} # end if
		} # end foreach Signature
	
		if ( ( !defined $$specs{'OverrideDiePrice'.$qty_index}) or ($$specs{'OverrideDiePrice'.$qty_index} ne 'Y') ) {
			$$specs{"DiePrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalDiePrice );
		} # end if
		if ( ( !defined $$specs{'OverrideStrippingPrice'.$qty_index}) or ( $$specs{'OverrideStrippingPrice'.$qty_index} ne 'Y' ) ) {
			$$specs{"StrippingPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalStrippingPrice );
		} else {
			$$specs{"StrippingPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"StrippingPrice$qty_index"} );
		} # end if
		if ( $$specs{'Markup'.$qty_index} ) {
			my $markup_amount = (1+$$specs{'Markup'.$qty_index}/100);
			$totalPrice *= $markup_amount;
			$totalUnitPrice *= $markup_amount;
			$totalMPrice *= $markup_amount;
		} # end if
		if ( $Project->markup() ) {
			my $markup_amount = (1+$Project->markup()/100);
			$totalPrice *= $markup_amount;
			$totalUnitPrice *= $markup_amount;
			$totalMPrice *= $markup_amount;
		} 
		if ( (!defined $$specs{'OverridePrice'.$qty_index}) or ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $totalPrice );
			@no_outputs = sets::exclude( ["txtPrice$qty_index"], \@no_outputs );
		} else {
			@no_outputs = sets::union( "txtPrice$qty_index", @no_outputs );
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $totalUnitPrice );
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $totalMPrice );

	} # end foreach qty

	return $status;
} # end sub calc

sub signature_needs {
	my ( $Project, $specs, $sig_specs ) = @_;
	my $form = $$sig_specs{SignatureIndex};
#$log->debug("Diecutting::signatureNeeds: for sig $form : Needed: ($$specs{'Needed-'.$form})" );
	if ( ! $$specs{"Needed-$form"} ) {
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
	return $$specs{"Needed-$form"} eq 'Y' ? 1 : 0;
} # end sub signature_needs

sub signature_calc {
	my ( $Project, $signature_service_index, $sig_specs, $specs, $qty_index, $Imposition ) = @_;

	my $form = $$sig_specs{SignatureIndex};

	@$specs{"txtWidth-$form", "txtHeight-$form"} = @$sig_specs{'txtWidth','txtHeight'};

	my %results;

	my @equipment;
	if ( (defined $$specs{"chkOverrideEquipment-$form-$qty_index"}) and ( $$specs{"chkOverrideEquipment-$form-$qty_index"} eq 'Y' ) ) {
		@equipment = ( new openprint::Equipment( $$specs{"ddmEquipment-$form-$qty_index"} ) );
	} else {
		@equipment = openprint::Equipment->find( useinestimating=>1, Specifications=>{'Die Cutting Capable'=>'Y'} );
	} # end if

	if ( (defined $$specs{"chkOverrideImposition-$form-$qty_index"}) and ( $$specs{"chkOverrideImposition-$form-$qty_index"} eq 'Y' ) ) {
		if ( $$specs{"txtImposition-$form-$qty_index"} > @$sig_specs{'txtImposition'.$qty_index} or $$specs{"txtImposition-$form-$qty_index"} <= 0 ) {
			$results{'alert'} = 'The specified imposition is not possible.';
			last;
		} # end if
	} # end if

	my $services = $Project->services();
	my @Sets_of_Impositions;

	if ( (defined $$specs{"OverrideImposition-$form-$qty_index"}) and ( $$specs{"OverrideImposition-$form-$qty_index"} eq 'Y' ) ) {
		$openprint::log->debug("Overriding impositions");

		my @override_impos;
		foreach my $index ( 1 .. 4 ) {
			next if ! $$specs{"ImpQty-$form-$qty_index-$index"};
			my $I = $Imposition->copy();
			$I->quantity( $$specs{"ImpQty-$form-$qty_index-$index"} );
			$I->imposition( $$specs{"ImpOut-$form-$qty_index-$index"} );
			$I->columns( $$specs{"ImpColumns-$form-$qty_index-$index"} );
			$I->rows( $$specs{"ImpRows-$form-$qty_index-$index"} );
			$I->Paper( $Imposition->Paper() );
			push @override_impos, $I;
			$I->display('Override');
		} # end foreach
		@Sets_of_Impositions = ( \@override_impos );
		my $overriden_count = misc::sum( map { $_->quantity() * $_->imposition() } @override_impos );
		if ( $overriden_count != $Imposition->quantity() * $Imposition->imposition() ) {
			$results{alert} .= "Overriden imposition count does not match printed imposition count for form $form.<br/>";
		} else {
			$openprint::log->debug(" override count: $overriden_count $$Imposition{quantity} * $$Imposition{imposition}");
		} # end if
	} else {
		@Sets_of_Impositions = ( [ $Imposition ] );
	} # end if Overrides

	foreach my $Equipment ( @equipment ) {
		if ( (defined $$specs{"txtHoleClearingHoles-$form"} ) and ( $$specs{"txtHoleClearingHoles-$form"} > 0 ) and ( $Equipment->specification('HoleClearing Capable') ne 'Y') ) {
			$results{breakdown} .= 'Doesnt do hole clearing.<br/>';
			next;
		} # end if

		for ( my $Set_index = 0; $Set_index < @Sets_of_Impositions; $Set_index += 1 ) {
			my $Set_of_Impositions =  $Sets_of_Impositions[$Set_index];
			my @Impositions = openprint::imposition::sort( @{$Set_of_Impositions} );

			my %price;
			my $complete = 1;
			for( my $impo_index = 0; $impo_index < @Impositions; $impo_index += 1 ) {
				my $imposition = $Impositions[$impo_index];

				my $width = $imposition->layout_width();
				my $height = $imposition->layout_height();
				if ( $_ = $Equipment->fits( $width, $height, $$sig_specs{txtSpecificStockCalliper} ) ) {
					if ( 1 == @equipment ) {
						$results{'breakdown'} .= "Doesn't fit. $_<br/>";
					} # end if
					if ( $$imposition{imposition} > 1 and ! $$specs{"OverrideImposition-$form-$qty_index"} ) {
						splice ( @Impositions, $impo_index, 1, openprint::imposition::cut( $imposition ) );
						push @Sets_of_Impositions,  \@Impositions;
					} # end if
					$complete = 0;
					last;
				} # end if
				my %p = calc_price( $specs, $Equipment, $qty_index, $imposition, $sig_specs, $Imposition );
				push @{$price{Prices}}, \%p;
				$price{Total} += $p{Total};
			} # end foreach imposition
			next if ! $complete;

			if ( (! $results{Total} ) or ( $price{Total} < $results{Total} ) ) {
				$results{Equipment} = $Equipment;
				@{$results{Prices}} = @{$price{Prices}};
				$results{'Overs'} = $price{'Overs'};
				$results{Total} = $price{Total};
			} # end if

		} # end foreach sets_of_impositions
	} # end foreach equipment
	return %results;
} # end sub signature_calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;	

	$$variable{Equipment} = [ openprint::Equipment->find(order=>'lower(strname)', 'useinestimating'=>1,'Specifications'=>{'Die Cutting Capable'=>'Y'} ) ];

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
			my $form = $$sig_specs{SignatureIndex};

			if ( (defined $$specs{'rdbSuppliedDie-'.$form} ) and ( $$specs{'rdbSuppliedDie-'.$form} eq 'Y' ) ) {
				$summary .= 'Customer supplies die' . ( @signatures > 1 ? ' for form '.$form : '' ).'<br/>';
			} else {
				$summary .= $Owner->name() . ' supplies die'.( @signatures > 1 ? ' for form '.$form : '' ).'<br/>';
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
