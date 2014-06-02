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

package openprint::Estimating::Drilling;

use POSIX qw(ceil);
use strict;

require openprint::Equipment;
require openprint::service;

my @variables = (
		'Markup1', 'Markup2', 'Markup3',
        'txtPrice1', 'txtPrice2', 'txtPrice3',
        'MPrice1', 'MPrice2', 'MPrice3',
        'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
		'txtHoleQty',
		'txtHoleSize',
		'ItemsPerLift','OverrideItemsPerLift',
		'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
		'chkOverrideEquipment1', 'chkOverrideEquipment2', 'chkOverrideEquipment3',
		'chkOverrideFinishedCalliper','txtFinishedCalliper',
        );

sub variables {
    return @variables;
} # end sub variables

my @outputs = (
        'txtPrice1', 'txtPrice2', 'txtPrice3',
        'MPrice1', 'MPrice2', 'MPrice3',
        'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
		'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
		'txtFinishedCalliper',
		'hdnBreakdown1', 'hdnBreakdown2', 'hdnBreakdown3',
		'alert','Status',
		'ItemsPerLift',
);
sub outputs {
	return @outputs;
}

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;
	
	$$specs{Status} = 'calculated';

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	if ( $$specs{'chkOverrideFinishedCalliper'} ne 'Y' ) {
		$$specs{'txtFinishedCalliper'} = $Project->calliper();
		@outputs = sets::union( 'txtFinishedCalliper', @outputs );
	} else {
		@outputs = sets::exclude( ['txtFinishedCalliper'], \@outputs );
	} # end if

	if ( ! ( 1*$$specs{txtFinishedCalliper} ) ) {
		$$specs{alert} = 'Please specify the finished calliper.';
		return $$specs{Status} = 'uncalculated';
	} # end if

	if ( $$specs{'txtHoleQty'} eq '' ) {
		$$specs{alert} = 'Please specify the # of holes.';
		return $$specs{Status} = 'uncalculated';
	} # end if

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] ) if $$services{''};

	my @capabilities = ( 'Y' );
	my $stitching_service_index;
    # Can only use the stitcher for drilling if we are stitching.  There are also thickness constraints
	if ( $$services{'SaddleStitching'} ) {
		$stitching_service_index = $$services{'SaddleStitching'}[0] ;
		push @capabilities, 'When Stitching';
	} elsif ( $$services{'LoopStitching'} ) {
		push @capabilities, 'When Stitching';
		$stitching_service_index = $$services{'LoopStitching'}[0];
	} # end if
	my $stitching_specs = openprint::service::get_specs_ref( $Project, $stitching_service_index ) if $stitching_service_index;

	my @possible_equipment = openprint::Equipment->find( 'Specifications' => {'Drilling Capable'=>\@capabilities}, 'useinestimating'=>1, order=>'strName');

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{"txtQuantity$qty_index"};
		$$specs{'Markup'.$qty_index} =~ s/[^\d\.\-]//g;
		$$specs{'txtPrice'.$qty_index} =~ s/[^\d\.]//g;
		my %BestPrice;
		$$specs{'hdnBreakdown'.$qty_index} = "QTY $qty_index ($qty):<br/>";
		$$specs{'hdnBreakdown'.$qty_index} .= 'Finished Calliper: ' . $$specs{txtFinishedCalliper}.'<br/>';
		if ( $$specs{'txtPressSheetComboItems'} > 1 ) {
			$qty *= $$specs{'txtPressSheetComboItems'};
		} # end if

		my @equipment;
		if ( $$specs{'chkOverrideEquipment'.$qty_index} eq 'Y' ) {
			@equipment = ( new openprint::Equipment( $$specs{'ddmEquipment'.$qty_index} ) );
			@outputs = sets::exclude( ['ddmEquipment'.$qty_index], \@outputs );
		} else {
			@equipment = @possible_equipment;
			@outputs = sets::union( 'ddmEquipment'.$qty_index, @outputs );
		} # end if

		foreach my $Equipment ( @equipment ) {
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf("<br/>Equipment: %s Lift: %s<br/>", $Equipment->name(), $Equipment->specification('Maximum Lift Depth') );
			if ( $Equipment->specification('Type') eq 'Stitcher' ) {
				if ( ! $stitching_service_index ) {
					$$specs{'hdnBreakdown'.$qty_index} .="Not stitching <br/>";
					next;
				} # end if
				if ( $$stitching_specs{'Imposition'.$qty_index} > 1 ) {
					$$specs{'hdnBreakdown'.$qty_index} .="Not when stitching more than 1 out<br/>";
					next;
				} # end if
				if ( $$stitching_specs{"ddmEquipment$qty_index"} != $Equipment->id() ) {
					$$specs{'hdnBreakdown'.$qty_index} .="Not stitching on this stitcher<br/>";
					next;
				} # end if

# Need to figure out which dimension the spine bisects
				my $spine_length;
				if ( ( $$printing_specs{'txtFinalWidth'} == $$printing_specs{'txtWidth'} ) and ( $$printing_specs{'txtFinalHeight'} != $$printing_specs{'txtHeight'} ) ) {
					$spine_length = $$printing_specs{'txtWidth'};
				} elsif ( ( $$printing_specs{'txtFinalWidth'} != $$printing_specs{'txtWidth'} ) and ( $$printing_specs{'txtFinalHeight'} == $$printing_specs{'txtHeight'} ) ) {
					$spine_length = $$printing_specs{'txtHeight'};
				} else {
					$spine_length = $$printing_specs{'txtHeight'};
					$$specs{'alert'} .= 'Unable to determine spine direction. Calculations may be invalid.';
				} # end if

				my $max_spine_length = $Equipment->specification('Drilling Maximum Spine Length', $$specs{'txtHoleQty'} );
				my $min_spine_length = $Equipment->specification('Drilling Minimum Spine Length', $$specs{'txtHoleQty'} );
				$$specs{'hdnBreakdown'.$qty_index} .= " Spine Length: $spine_length, min: $min_spine_length, max: $max_spine_length<br/>";
				if ( $max_spine_length and ( $max_spine_length < $spine_length ) ) {
					$$specs{'hdnBreakdown'.$qty_index} .= " Spine too long.\n";
					next;
				} # end if
				if ( $min_spine_length and ( $min_spine_length > $spine_length ) ) {
					$$specs{'hdnBreakdown'.$qty_index} .= " Spine too short.\n";
					next;
				} # end if
			} # end if
			if ( $Equipment->specification('Hole Sizes') and ! sets::isin( $$specs{'txtHoleSize'}, [split ',', $Equipment->specification('Hole Sizes', $$specs{'txtHoleQty'} ) ] ) ) {
				$$specs{'hdnBreakdown'.$qty_index} .= " Doesn't support $$specs{'txtHoleSize'}\" holes.\n";
				next;
			} # end if
			if ( $Equipment->specification('Maximum Lift Depth') and $Equipment->specification('Maximum Lift Depth') < $$specs{txtFinishedCalliper} ) {
				$$specs{'hdnBreakdown'.$qty_index} .= " Too thick.\n";
				next;
			} # end if
			if ( ! $Equipment->specification('Number of Drills') ) {
				$$specs{'hdnBreakdown'.$qty_index} .= " has no drills!\n";
				next;
			} # end if

			my $minPrice = openprint::service::get_price( 'DrillingChargeMinimum', undef, $Equipment );
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Minimum Charge: $%.2f<br/>', $minPrice );

			my $price = 0;
			my $mprice = 0;

			my $items_per_lift;
			if ( $$specs{'OverrideItemsPerLift'} ne 'Y' ) {
				if ( ( $$services{'Scoring'} or $$services{'Perforating'} ) and $Equipment->specification('PerfScoreDrillingItemsPerLift') ) {
					$items_per_lift = $Equipment->specification('PerfScoreDrillingItemsPerLift');
					$$specs{'hdnBreakdown'.$qty_index} .= 'Settings items per lift to 10 because the items are scored or perfed<br/>';
				} elsif ( $Equipment->specification('Maximum Lift Depth') ) {
					$items_per_lift = int($Equipment->specification('Maximum Lift Depth')/$$specs{txtFinishedCalliper});
				} else {
					$items_per_lift = 1;
				} # end if
			} else {
				$items_per_lift = $$specs{'ItemsPerLift'};
			} # end if

			my $makeReady = openprint::service::get_price( 'DrillingMakeReady', $$specs{'txtHoleQty'}, $Equipment );
			$$specs{'hdnBreakdown'.$qty_index} .= "MakeReadyPrice: $makeReady<br/>";
			my %servicePrice = openprint::service::get_price_object( 'Drilling', $qty, $Equipment);
			if ( ! %servicePrice ) {
				$$specs{'hdnBreakdown'.$qty_index} .= "No Service Price found for this quantity.<br/>";
				next;
			} # end if
				my $heads = $Equipment->specification('Number of Drills');
				my $runs = $heads ? ceil( $$specs{'txtHoleQty'} / $heads ) : 1;
			if ( sets::isin( $servicePrice{'units'}, 'per m', 'per 1000' ) ) {
				%servicePrice = openprint::service::get_price_object( 'Drilling', $runs * $qty, $Equipment);
				$servicePrice{'Total'} = $runs * $qty * ($servicePrice{Price}/1000);
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('ServicePrice: %d * %.3f %s = $%.2f<br/>',$qty, $servicePrice{'Price'}/1000, @servicePrice{'units','Total'} );
			} elsif ( sets::isin( $servicePrice{'units'}, [ 'per lift', 'per drill' ] ) ) {
				if ( $items_per_lift ) {
					$runs *= ceil($qty/$items_per_lift);
					$$specs{'hdnBreakdown'.$qty_index} .= "$items_per_lift Items per lift = $runs lifts.<br/>";
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= "$runs runs.<br/>";
				} # end if

				$servicePrice{'Total'} = $runs * $servicePrice{Price};
				$$specs{'hdnBreakdown'.$qty_index} .= "ServicePrice: $runs lifts * $servicePrice{'Price'} $servicePrice{'units'} = $servicePrice{'Total'}<br/>";
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units ( $servicePrice{'units'} ) for service price!<br/>";
			} # end if

			$price = $makeReady + $servicePrice{'Total'};
			if ( $minPrice > 0 and $price < $minPrice ) {
				$price = $minPrice;
			} # end if
			if ( $price < $BestPrice{'Total'} or ! %BestPrice ) {
				$BestPrice{'Total'} = $price;
				$BestPrice{'Equipment'} = $Equipment;
				$BestPrice{'ItemsPerLift'} = $items_per_lift;
				$BestPrice{'MPrice'} = ( $servicePrice{'Total'} / $qty ) * 1000;
			} # end if
		} # end foreach equipment_id

		if ( ! %BestPrice ) {
			$$specs{'Status'} = 'uncalculated';
			next;
		} # end if

		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, 
					$BestPrice{'Total'}*(1+$$specs{"Markup$qty_index"}/100)*(1+$Project->markup()/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, 
				( $BestPrice{'Total'} / $qty ) * (1+$Project->markup()/100) );
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $BestPrice{'MPrice'} * (1+$Project->markup()/100) );
		$$specs{"ddmEquipment$qty_index"} = $BestPrice{'Equipment'}->id();
		if ( $$specs{'OverrideItemsPerLift'} ne 'Y' ) {
			$$specs{'ItemsPerLift'} = $BestPrice{'ItemsPerLift'};
		} # end if

	} # end foreach qty_index

	return $$specs{'Status'};
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	my @capabilities = ( 'Y', 
		( ( $$services{SaddleStitching} or $$services{LoopStitching} ) ? 'When Stitching' : () ),
	);
	my @equipment = openprint::Equipment->find( 'Specifications' => {'Drilling Capable'=>\@capabilities}, useinestimating=>1, order=>'strName');
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$variable{'ddmEquipment'.$qty_index} = ssi::make_drop_down( [ map { $_->id(), $_->name() } @equipment ], $$variable{'ddmEquipment'.$qty_index} );
	} # end foreach qty_index

}  # end sub display

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	if ( $qty_index ) {
	} else {
		return $$specs{'txtHoleQty'} . ' ' . $$specs{'txtHoleSize'} . '&quot; holes';
	} # end if
	return '';
} # end sub summary

sub runtime {
    my ( $p_id, $s_id, $specs, $qty_index ) = @_;
    return 0 if ! $$specs{'ddmEquipment'.$qty_index};

    my $runtime;
	my $Equipment = new openprint::Equipment( $$specs{'ddmEquipment'.$qty_index} );
	my $makeready = $Equipment->specification( 'Make Ready Time', undef );
	my $runspeed = $Equipment->specification( 'Run Speed', undef );
	my $runs = $$specs{'txtHoleQty'};

# Should be the # of drills in the machine
	$runs = ceil($runs/3);
	$runtime = $makeready * 60 + ( $$specs{'txtQuantity'.$qty_index} * $runs * 3600 / $runspeed );
	$openprint::log->debug("Drilling: $runtime");
	return $runtime;
} # end sub runtime

sub save {
} # end sub save

sub has_overrides {
    my ( $Project, $service_id, $specs, $qty_index ) = @_;
    $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

    my @v;
    if ( ! $qty_index ) {
        push @v, map { $$specs{$_} ? $_ : () } ( 'chkOverrideFinishedCalliper', 'OverrideItemsPerLift' );
    } else {
        foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, map { $$specs{$_.$qty_index} ? $_.$qty_index : () } ( 'chkOverrideEquipment' );
        } # end foreach
    } # end if

    return @v;
} # end sub has_overrides

1;
__END__
