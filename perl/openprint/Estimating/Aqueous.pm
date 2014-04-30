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

package openprint::Estimating::Aqueous;
use strict;
#use warnings;

require sql;
require openprint::service;
require openprint::Material;
require openprint::imposition;
require openprint::Imposition;

use vars qw( @outputs );
use constant DEBUG => 0;

# Offline Aqueous
# Let's assume that each piece of equipment can do 1 coat at a time
# This service doesn't store it's own data, other than price.  It gets the info from the printing service.
#
my @variables = (
	'alert',
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'Markup1', 'Markup2', 'Markup3',
	'txtPrice1','txtPrice2','txtPrice3',
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
);

sub variables {
	my $p_id = shift;

	my $Project = new openprint::Project( $p_id );
	my @v = @variables;
	foreach my $s_s_id ( $Project->signatures() ) {
		my $specs = openprint::service::get_specs_ref( $Project, $s_s_id );
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, 
				 "ddmEquipment-$$specs{'SignatureIndex'}-$qty_index", "chkOverrideEquipment-$$specs{'SignatureIndex'}-$qty_index",
				 "txtImposition-$$specs{'SignatureIndex'}-$qty_index", "chkOverrideImposition-$$specs{'SignatureIndex'}-$qty_index",
				 "txtLayoutWidth-$$specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$specs{'SignatureIndex'}-$qty_index",
				 "MakeReadyPrice-$$specs{'SignatureIndex'}-$qty_index", "OverrideMakeReadyPrice-$$specs{'SignatureIndex'}-$qty_index", 
				 "BlanketPrice-$$specs{'SignatureIndex'}-$qty_index", "OverrideBlanketPrice-$$specs{'SignatureIndex'}-$qty_index", 
				 "ServicePrice-$$specs{'SignatureIndex'}-$qty_index", "OverrideServicePrice-$$specs{'SignatureIndex'}-$qty_index", 
				 "MaterialPrice-$$specs{'SignatureIndex'}-$qty_index", "OverrideMaterialPrice-$$specs{'SignatureIndex'}-$qty_index", 
				 "SignaturePrice-$$specs{'SignatureIndex'}-$qty_index", "OverrideSignaturePrice-$$specs{'SignatureIndex'}-$qty_index", 

		} # end foreach
	} # end foreach
    return @v;
} # end sub variables

@outputs = (
	'txtUnitPrice1','txtUnitPrice2','txtUnitPrice3',
	'txtPrice1','txtPrice2','txtPrice3',
	'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
	'hdnBreakdown1',
	'hdnBreakdown2',
	'hdnBreakdown3',
	'alert',
);
sub outputs {
	return @outputs;
}
sub no_outputs {
} # end sub no_outputs

my @no_outputs = (
);

my @all_equipment;

# A function that is smart enough to return true if the project needs perfing/Aqueous, and false if it doesn't.
sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	return 0;
} # end sub neccessary

sub get_colours {
    my ( $specs, $side ) = @_;
    my @colours;
    if ( ( defined $$specs{'sides_the_same'} ) and ( $$specs{'sides_the_same'} eq 'Y' ) and ( $side eq 'SideTwo' ) ) {
        $side = 'SideOne';
    } # end if

    foreach my $k ( keys %$specs ) {
#$openprint::log->debug("AQ get_colours $k => $$specs{$k}");
        if ( my ( $index ) = $k =~ /^chkColourCoating(\d+)$side/ ) {
#$openprint::log->debug("AQ get_colours $k => $$specs{$k} index is $index");
            next if ! $$specs{"chkColourCoating$index$side"};
			if ( $$specs{"ColourCoatingType$index$side"} =~ /Aqueous/i ) {
				push @colours, $$specs{"ColourCoatingType$index$side"};
            } # end if
        } # end if
    } # end foreach
    return @colours;
} # end sub get_colours

sub signature_needs {
	my ( $Project, $sig_specs ) = @_;

	if ( $$sig_specs{SideOneColours} ) {
		foreach ( @{$$sig_specs{SideOneColours}} ) {
			return 1 if $$_{'name'} =~ /Aqueous/;
		} # end foreach colour
	} else {
		$$sig_specs{SideOneAQ} = [ get_colours( $sig_specs, 'SideOne' ) ] if ! $$sig_specs{SideOneAQ};
		return 1 if @{$$sig_specs{SideOneAQ}};
	} # en dif

	if ( $$sig_specs{SideTwoColours} ) {
	foreach ( @{$$sig_specs{SideTwoColours}} ) {
		return 1 if $$_{'name'} =~ /Aqueous/;
	} # end foreach colour
	} else {
		$$sig_specs{SideTwoAQ} = [ get_colours( $sig_specs, 'SideTwo' ) ] if ! $$sig_specs{SideTwoAQ};
		return 1 if @{$$sig_specs{SideTwoAQ}};
	} # en dif
} # end sub signature_needs

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';
	$$specs{alert} = '';

	my $Project = new openprint::Project( $project_index );

	@all_equipment = openprint::Equipment->find( Specifications => {'Aqueous Capable'=>['Y','When Printing']}, useinestimating=>1, order=>'lower(strName)') if ! @all_equipment;

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g if $$specs{"Markup$qty_index"};
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g if $$specs{"txtPrice$qty_index"};
		$$specs{"txtQuantity$qty_index"} =~ s/\D//g if $$specs{"txtQuantity$qty_index"};
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! ( $$specs{"txtQuantity$qty_index"} > 0 ) ) {
			next;
		} # end if
		$$specs{'hdnBreakdown'.$qty_index} = sprintf('QTY: %d<br/>',$$specs{"txtQuantity$qty_index"} );

		my $qty = $$specs{"txtQuantity$qty_index"};
		if ( $$specs{'txtPressSheetComboItems'} ) {
			$$specs{'txtPressSheetComboItems'} =~ s/\D//g;
			if ( $$specs{'txtPressSheetComboItems'} ) {
				$qty *= $$specs{'txtPressSheetComboItems'} 
			} else {
				$$specs{alert} .= 'Combination items is invalid.';
			} # end if
		} # end if

		my %MakeReadies;

		my $GrandTotal = 0;
		foreach my $signature_service_index ( $Project->signatures( { sort=>1 } ) ) {
			my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
			$$specs{'hdnBreakdown'.$qty_index} .= "<br/>Signature: $$sig_specs{'txtServiceDescription'},<br/>" if $$sig_specs{'txtServiceDescription'} ne '';
# If any of the signatures doesn't have an imposition, then we are in an incomplete state.
			if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No imposition was found for printing.<br/>';
				next;
			} # end if
			my $Imposition = new openprint::Imposition();
			$Imposition->load( $sig_specs, $qty_index );
			my %results = signature_calc( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $Imposition, \%MakeReadies );
			$MakeReadies{$results{'Equipment'}->id()} = $Imposition->layout_area() if $results{'Equipment'};
			@outputs = sets::union( @outputs, 
					"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index",
					"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index",
					"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index", "txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index",
					"MakeReadyPrice-$$sig_specs{'SignatureIndex'}-$qty_index",
					"BlanketPrice-$$sig_specs{'SignatureIndex'}-$qty_index",
					"ServicePrice-$$sig_specs{'SignatureIndex'}-$qty_index",
					"MaterialPrice-$$sig_specs{'SignatureIndex'}-$qty_index",
					"SignaturePrice-$$sig_specs{'SignatureIndex'}-$qty_index",
					);	
			if ( $$specs{"OverrideMakeReadyPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"MakeReadyPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} = sprintf($openprint::config{ProjectMoneyFormat}, $results{'MakeReady'} );
			} # end if
			if ( $$specs{"OverrideBlanketPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"BlanketPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} = sprintf($openprint::config{ProjectMoneyFormat}, $results{'BlanketCut'} );
			} # end if
			if ( $$specs{"OverrideServicePrice-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"ServicePrice-$$sig_specs{'SignatureIndex'}-$qty_index"} = sprintf($openprint::config{ProjectMoneyFormat}, $results{'Service'} );
			} # end if
			if ( $$specs{"OverrideMaterialPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"MaterialPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} = sprintf($openprint::config{ProjectMoneyFormat}, $results{'Material'} );
			} # end if
			if ( $$specs{"OverrideSignaturePrice-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"SignaturePrice-$$sig_specs{'SignatureIndex'}-$qty_index"} = sprintf($openprint::config{ProjectMoneyFormat}, $results{'Total'} );
			} # end if
			if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' ) {
				$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = '';
			} # end if
			if ( $results{'Status'} eq 'uncalculated' ) {
				$status = 'uncalculated';
				if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
					$$specs{'alert'} = "The selected equipment can not handle your project.  This may be because the stock is too heavy, or too large.";
				} else {
					$$specs{'alert'} = "No suitable equipment could be found for your project.  This may be because the stock is too heavy, or too large.";
				} # end if
			} else {

				if ( $results{'Equipment'} ) {
					$$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Equipment'}->id();
					$GrandTotal += $$specs{"SignaturePrice-$$sig_specs{'SignatureIndex'}-$qty_index"};
					$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Imposition'}->imposition();
					$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Imposition'}->layout_width();
					$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = $results{'Imposition'}->layout_height();
				} else {
					$$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
					$$specs{"txtLayoutWidth-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
					$$specs{"txtLayoutHeight-$$sig_specs{'SignatureIndex'}-$qty_index"} = 0;
				} # end if
			} # end if uncalculated
		} # end foreach signature

		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, ( $GrandTotal / $qty ) * (1+$Project->markup()/100) );
		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $GrandTotal*(1+$$specs{"Markup$qty_index"}/100)*(1+$Project->markup()/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $$specs{'txtPrice'.$qty_index} );
		} # end if
	} # end foreach qty

	return $status;

} # end sub calc

sub signature_calc {
    my ( $Project, $service_index, $specs, $signature_service_index, $sig_specs, $qty_index, $imposition, $MakeReadies ) = @_;

if ( DEBUG ) {
foreach my $equipment_id ( keys %{$MakeReadies} ) {
$openprint::log->debug("Makereadies $equipment_id $$MakeReadies{$equipment_id}");
}
}

	my %bestPrice;
	$bestPrice{'Status'} = 'uncalculated';

	my @front_aq;
    $$sig_specs{SideOneColours} = [openprint::Estimating::Printing::get_colours( $sig_specs, 'SideOne' )] if ! $$sig_specs{SideOneColours};
	foreach ( @{$$sig_specs{SideOneColours}} ) {
#$openprint::log->debug("blah  $$_{name}");
		if ( $$_{'name'} =~ /Aqueous/ ) {
			push @front_aq, $$_{'name'};
			#$openprint::log->debug("Side one Aqueous: $_");
		} # end if
	} # end foreach colour

	my @back_aq;
    $$sig_specs{SideTwoColours} = [openprint::Estimating::Printing::get_colours( $sig_specs, 'SideTwo' )] if ! $$sig_specs{SideTwoColours};
	foreach ( @{$$sig_specs{SideTwoColours}} ) {
		if ( $$_{'name'} =~ /Aqueous/ ) {
			push @back_aq, $$_{'name'};
			#$openprint::log->debug("Side two Aqueous: $_");
		} # end if
	} # end foreach colour

	$openprint::log->debug("Signature : $signature_service_index") if DEBUG;
	if ( ! ( @front_aq or @back_aq ) ) {
$openprint::log->warn("Doing AQ when not needed @front_aq @back_aq");
		$bestPrice{'Status'} = 'calculated';	
		return %bestPrice;
	} # end if
	my %inkCoverage = openprint::Estimating::Printing::get_inkcoverage( $Project, $sig_specs );

	my @different_types = sets::union( @front_aq, @back_aq );

	# Should include overs
	my $impressions = $$sig_specs{"hdnImpressionQuantity$qty_index"} ? $$sig_specs{"hdnImpressionQuantity$qty_index"} : $$specs{"txtQuantity$qty_index"};
$openprint::log->debug("Impressions: " . $$sig_specs{"hdnImpressionQuantity$qty_index"} . " qty: " . $$specs{"txtQuantity$qty_index"} ) if DEBUG;

	# Why would it be multiplied by the # of items per sheet? That doesn't make any sense at all.
	#if ( $$specs{'txtPressSheetComboItems'} ) {
		#$impressions *= $$specs{'txtPressSheetComboItems'};
	#} # end if
	#if ( $$sig_specs{'Versions'} ) {
		#$impressions *= $$sig_specs{'Versions'};
	#} # end if
$openprint::log->debug("Impressions: $impressions") if DEBUG;
if ( 1 ) {
	# This just can't be right anymore. Actually it can... if double sided, impressions are doubled...
	if ( $imposition->runstyle() eq 'Perfecting' ) {
		# We know that it is printing 2 sided, but may be only AQ 1 sided.
		# Sheets = impressions / 2
		$impressions = int($impressions/2);
	} elsif ( $$imposition{runstyle} eq 'Sheet Work' ) {
		if ( @{$$sig_specs{SideOneColours}} and @{$$sig_specs{SideTwoColours}} ) {
# 20140417 : so... since the AQs are added together, done in sequence, we do front first, then back, using the impression count... so it should always be halved
			#if ( ! ( @front_aq and @back_aq ) ) {
				$impressions = int($impressions/2);
			#} # end if
		} # end if
	} # end if
} # end if
$openprint::log->debug("Impressions: $impressions") if DEBUG;

	@all_equipment = openprint::Equipment->find( Specifications => {'Aqueous Capable'=>['Y','When Printing']}, useinestimating=>1,order=>'lower(strName)') if ! @all_equipment;
	my @equipment;	
	if ( $$specs{"chkOverrideEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		@equipment = ( new openprint::Equipment( $$specs{"ddmEquipment-$$sig_specs{'SignatureIndex'}-$qty_index"} ) );
	} else {
		@equipment = @all_equipment;
	} # endif

	if ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		if ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} > $imposition->imposition() or $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} <= 0 ) {
			$$specs{'alert'} .= 'The specified imposition is not possible.<br/>';
			return %bestPrice;
		} # end if
	} # end if

	my @impositions = ();
	my $services = $Project->services();
	if ( 0 and $$services{'Cutting'} ) {
		$openprint::log->debug('Cutting');
		my @imps = openprint::imposition::get_all_impositions( $imposition );
		$openprint::log->debug('After get all Cutting' . @imps);
		for ( my $i = 0; $i < @imps; $i += 1 ) {
			$openprint::log->debug("Imposition: " . $imps[$i]{'imposition'} . 'out' );
			if ( ( $$specs{"chkOverrideImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} ne 'Y' )
					or ( $$specs{"txtImposition-$$sig_specs{'SignatureIndex'}-$qty_index"} == $imps[$i]->imposition() )
			   ) {
				push @impositions, $imps[$i];
			} # end if

# Remove any other impositions that have the same setup
			for ( my $j = $i + 1; $j < @imps; $j += 1 ) {
				if ( $imps[$i]->imposition() == $imps[$j]->imposition() and $imps[$i]->rows() == $imps[$j]->rows() ) {
					splice @imps, $j, 1;
					$j -= 1;
				} # end if
			} # end for
		} # end for
	} else {
		@impositions = ( $imposition->copy() );
	} # end if
	$openprint::log->debug('AQ DOne Cutting :' . @impositions) if DEBUG;

	foreach my $Equipment ( @equipment ) {
$openprint::log->debug("AQ Equipment $$Equipment{strid}") if DEBUG;
		$$specs{'hdnBreakdown'.$qty_index} .= 'Equipment: '.$Equipment->strid().' ' . $Equipment->specification('Aqueous Capable') . ' ' . $$sig_specs{'ddmPress'.$qty_index} . ',<br/>';
		if ( $Equipment->specification('Aqueous Capable') eq 'When Printing' ) {
			if ( $$sig_specs{'ddmPress'.$qty_index} ne $Equipment->strid() ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Not printing on this press.<br/>';
				next;
			} elsif ( @front_aq and @back_aq and ( $imposition->runstyle() eq 'Perfecting' ) and ! $Equipment->specification('Aqueous Double Sided When Perfecting') ) {
				$$specs{'hdnBreakdown'.$qty_index} .= 'Cant perfect with double sided AQ.<br/>';
				next;
			} # end if
		} # end if
		my %minimum = openprint::service::get_price_object( 'AqueousMinimumCharge', undef, $Equipment );

		foreach my $imp ( @impositions ) {
			my %MakeReadies = $MakeReadies ? %$MakeReadies : ();
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Imposition: %dx%d+%dx%d=%dout %s:', @$imp{'columns','rows','dutch_columns','dutch_rows','imposition','runstyle'} );
			next if ! ( $imp->rows() * $imp->columns() );
			my $width = $imposition->sheet_width() / ( $imposition->columns()/$imp->columns() );
			my $height = $imposition->sheet_height() / ( $imposition->rows()/$imp->rows() );
			$$specs{'hdnBreakdown'.$qty_index} .= $imposition->sheet_width().'x'.$imposition->sheet_height().'=>'.$width.'x'.$height.'<br/>';

			if ( $_ = $Equipment->fits( $width, $height, $$sig_specs{'txtSpecificStockCalliper'} ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit. $_<br/>";
				next;
			} # end if

			my %Price;
			my $run_qty = $impressions;
#$openprint::log->debug("Run QTY: $run_qty $$imposition{imposition} / $$imp{imposition} ");
			$run_qty += ( $imposition->imposition() / $imp->imposition() ) if $imposition->imposition() != $imp->imposition();
#$openprint::log->debug("Run QTY: $run_qty $$imposition{imposition} / $$imp{imposition} ");

			my @types;
			if ( sets::isin( $imposition->runstyle(), ['Work & Turn', 'Work & Tumble'] ) ) {
# need to merge any overalls into spots
				foreach my $type ( @different_types ) {
					if ( ! ( sets::isin( $type, \@front_aq ) and sets::isin( $type, \@back_aq ) ) ) {
						$type =~ s/Overall/Spot/;
					} # end if
					push @types, $type;
				} # end foreach
				# In W&T, the impression count is total impressions, so both sides already, so no need to multiply
				#$run_qty *= 2;
			} else {
				@types = (@front_aq, @back_aq);
			} # end if
			my $area = $imp->layout_area();
$openprint::log->debug("AQ types @types") if DEBUG;
			foreach my $type ( @types ) {

				my %setupPrice;
#$openprint::log->debug("Makereadies: $$Equipment{id} $area");
				if ( $MakeReadies{$Equipment->id()} and (
							(($area * 1.10 ) > $MakeReadies{$Equipment->id()} ) and
							(($area * .90 ) < $MakeReadies{$Equipment->id()} )
							) ) {
#$openprint::log->debug("In Makereadies: $$Equipment{id} $area");
				} else {
					my $MRService = openprint::Service->find_one('name'=>$type.' MakeReady');
					$MRService = openprint::Service->find_one('name'=>'AqueousMakeReady') if ! $MRService;
					if ( ! $MRService ) {
						$$specs{'hdnBreakdown'.$qty_index} = 'No Make Ready Service for ' . $type . '<br/>';
					} else {
						%setupPrice = $MRService->get_price( $run_qty, $Equipment );
					} # end if
					$Price{'MakeReady'} += $setupPrice{'Price'};
					$MakeReadies{$Equipment->id()} = $area;
					$Price{washups} = scalar @different_types;
				} # end if
				
				my %BlanketCutPrice;
				if ( $type =~ /Spot/ ) {
					%BlanketCutPrice = openprint::service::get_price_object( 'AqueousBlanketCut', undef, $Equipment );
					%BlanketCutPrice = openprint::service::get_price_object( 'BlanketCut', undef, $Equipment ) if ! %BlanketCutPrice;
				} # end if type is spot
				$Price{'BlanketCut'} += $BlanketCutPrice{'Price'};

				my $Service = openprint::Service->find_one('name'=>$type);
				if ( ! $Service ) {
					$$specs{'hdnBreakdown'.$qty_index} = 'No Service for ' . $type . '<br/>';
					next;
				} # end if

				my %ServicePrice = $Service->get_price( $run_qty, $Equipment );
				if ( ! %ServicePrice ) {
					$$specs{'hdnBreakdown'.$qty_index} = 'No Service price for ' . $type . '<br/>';
					$ServicePrice{'Total'} = 1000000;
				} # end if
				if ( sets::isin( lc $ServicePrice{'units'}, [ 'per 1000 impressions' ] ) ) {
					%ServicePrice = $Service->get_price( $impressions, $Equipment );
					$ServicePrice{'Quantity'} = $impressions;
					$ServicePrice{'Total'} = $ServicePrice{'Price'} * $impressions / 1000;
				} elsif ( sets::isin( lc $ServicePrice{units}, [ 'per m', 'per 1000' ] ) ) {
					$ServicePrice{Quantity} = $run_qty;
					$ServicePrice{Total} = $ServicePrice{Price} * $run_qty / 1000;
				} elsif ( lc $ServicePrice{'units'} eq 'per hour' ) {
					$ServicePrice{'Quantity'} = $run_qty;
					$ServicePrice{'Total'} = $ServicePrice{'Price'} * $run_qty / $Equipment->specification('AqueousRunSpeed') if $Equipment->specification('AqueousRunSpeed');
				} # end if
# Div by imposition
				#$ServicePrice{'Total'} /= $imp->imposition();
				$Price{'Service'} += $ServicePrice{'Total'};

				my %MaterialPrice;
				my $material_name = $type;
				$material_name =~ s/ ?Spot ?//;
				$material_name =~ s/ ?Overall ?//;
				my $Material = openprint::Material->find_one('name'=>$material_name);
				if ( ! $Material ) {
					$material_name = 'Aqueous';
					$Material = openprint::Material->find_one('name'=>$material_name);
				} # end if
				if ( ! $Material ) {
					$$specs{'hdnBreakdown'.$qty_index} .= 'No material for aqueous found.<br/>';
				} else {
					%MaterialPrice = $Material->get_price( $run_qty, $Equipment );
					if ( lc $MaterialPrice{'units'} eq 'per square inch' ) {
						my $area = $imp->object_area() * $run_qty * ($inkCoverage{$type}/100);
						$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $run_qty * $area;
					} elsif ( lc $MaterialPrice{'units'} eq 'per square foot' ) {
						my $area = $imp->object_area() * $run_qty * ($inkCoverage{$type}/100) /144;
						$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $area;
					} elsif ( lc $MaterialPrice{'units'} eq 'per 1000 square feet' ) {
						my $area = $imp->object_area() * $run_qty * ($inkCoverage{$type}/100) /144;
# area is # of square feet
						$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $area/1000;
					} elsif ( lc $MaterialPrice{'units'} eq 'per m' ) {
						$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $run_qty / 1000;
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units for Material $material_name ($MaterialPrice{'units'})<br/>";
					} # end if
					$Price{'Material'} += $MaterialPrice{'Total'};
				} # end if

				my $colour_total += $setupPrice{'Price'} + $MaterialPrice{'Total'} + $ServicePrice{'Total'} + $BlanketCutPrice{'Price'};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MR: $%.2f + BC: $%.2f + Service: ($%.2f%s*%d)=$%.2f + Material: $%.2f%s = $%.2f ) = $%.2f<br/>',
					$setupPrice{'Price'}, $BlanketCutPrice{'Price'}, @ServicePrice{'Price','units','Quantity','Total'}, @MaterialPrice{'Price','units','Total'}, $colour_total );
			} # end foreach type
			$Price{'Total'} = $Price{'MakeReady'} + $Price{'Service'} + $Price{'Material'} + $Price{'BlanketCut'};
			if ( $Price{'Total'} < $minimum{Price} ) {
				$Price{'Total'} = $minimum{Price};
			} # end if

			if ( $Price{'Total'} < $bestPrice{'Total'} or ( ! defined $bestPrice{'Total'} ) ) {
				$bestPrice{'Total'} = $Price{'Total'};
				$bestPrice{'MakeReady'} = $Price{'MakeReady'};
				$bestPrice{'Service'} = $Price{'Service'};
				$bestPrice{'Material'} = $Price{'Material'};
				$bestPrice{'BlanketCut'} = $Price{'BlanketCut'};
				$bestPrice{'Equipment'} = $Equipment;
				$bestPrice{'Imposition'} = $imp;
				$bestPrice{washups} = $Price{washups};
			} # end if
		} # end foreach equipment
	} # end foreach imposition

	if ( defined $bestPrice{'Total'} ) {
		$bestPrice{'Status'} = 'calculated';
	} # end if

	if ( $$specs{"OverrideMakeReadyPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		$bestPrice{'MakeReady'} = $$specs{"MakeReadyPrice-$$sig_specs{'SignatureIndex'}-$qty_index"};
	} # end if
	if ( $$specs{"OverrideBlanketPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		$bestPrice{'BlanketCut'} = $$specs{"BlanketPrice-$$sig_specs{'SignatureIndex'}-$qty_index"};
	} # end if
	if ( $$specs{"OverrideServicePrice-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		$bestPrice{'Service'} = $$specs{"ServicePrice-$$sig_specs{'SignatureIndex'}-$qty_index"};
	} # end if
	if ( $$specs{"OverrideMaterialPrice-$$sig_specs{'SignatureIndex'}-$qty_index"} eq 'Y' ) {
		$bestPrice{'Material'} = $$specs{"MaterialPrice-$$sig_specs{'SignatureIndex'}-$qty_index"};
	} # end if
	$bestPrice{'Total'} = misc::sum( @bestPrice{'MakeReady','BlanketCut','Service','Material'} );
	return %bestPrice;
} # end sub signature_calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;
#$openprint::log->debug('Aqueous');
	@{$$variable{'Equipment'}} = openprint::Equipment->find( 'Specifications' => {'Aqueous Capable'=>['Y','When Printing']}, 'useinestimating'=>1,'order'=>'lower(strName)');
} # end sub display

# Copies the AQ settings back into the printing service, because that is where we have chosen to store them.
sub save {
	my ( $p_id, $s_id, $params ) = @_;
	my $Project = new openprint::Project( $p_id );
} # end sub

sub summary {
	return '';
} # end sub summary


1;

__END__
