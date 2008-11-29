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

package openprint::Estimating::Lamination;
use POSIX qw{ ceil };
use strict;

require openprint::project;
require openprint::Equipment;
require openprint::service;

require sql;

my @variables = (
	'txtFinalWidth','txtFinalHeight','chkOverrideDimensions',
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1', 'Markup2', 'Markup3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
	'chkOverrideEquipment1', 'chkOverrideEquipment2', 'chkOverrideEquipment3',
	'LaminationType',
);

sub variables {
	return @variables;
} # end sub variables

my @outputs = (
	'txtFinalWidth','txtFinalHeight',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
	'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
	'alert', 'Status',
	'hdnBreakdown1', 'hdnBreakdown2', 'hdnBreakdown3',
);

sub outputs {
	return @outputs;
}

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();

	my $printing_specs = openprint::service::get_specs_ref( $project_index, $services{''}[0] );
	if ( $$specs{'chkOverrideDimensions'} ne 'Y' ) {
		@$specs{'txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	} # end if

	if ( ! 
			( $$specs{'LaminationType'} and $$specs{'txtFinalWidth'} and $$specs{'txtFinalHeight'} )
	   ) {
		$$specs{'txtPrice1'} = '';
		$$specs{'txtPrice2'} = '';
		$$specs{'txtPrice3'} = '';
		$$specs{'txtUnitPrice1'} = '';
		$$specs{'txtUnitPrice2'} = '';
		$$specs{'txtUnitPrice3'} = '';
		return 'uncalculated';
	} # end if

	my %MinimumCharge = openprint::service::get_price_object( $$specs{'ServiceType'}.'MinimumCharge', undef, undef );

	my %MaterialPrice;
	if ( my @Materials = openprint::Material::find( 'name'=>$$specs{'LaminationType'} ) ) {
		%MaterialPrice = $Materials[0]->get_price( undef, undef );
	} # en if

   my @possible_equipment;
   my @all_equipment = openprint::Equipment::find( 'Specifications' => {'Laminating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'lower(strName)');

    if ( ! @all_equipment ) {
      	$$specs{'alert'} = 'We have no laminating equipment.';
		return 'uncalculated';
    } # end if
    my $error = '';
    foreach my $Equipment ( @all_equipment ) {
        if ( 
			(my $reason1 = $Equipment->fits( $$specs{'txtFinalWidth'} ) ) and
			(my $reason2 = $Equipment->fits( $$specs{'txtFinalHeight'} ) ) 
		   ) {
            $error .= 'For ' . $Equipment->name() . ': '. $reason1  . '<br/>' . $reason2;
        } else {
            push @possible_equipment, $Equipment
        } # end if
    } # end foreach

	if ( ! @possible_equipment ) {
		$$specs{'alert'} = "Our equipment cannot run this project, for the following reasons:\n$error\n Please only print flat sheets and contact another bindery.";
		return 'uncalculated';
	} # end if

	# So we can do multiple items at once, as many as will fit in the wiwdth of the laminator.  We need a certain amount of space between the items.  I suspect that this should be an input, not a fixed value, but for now we will make it fixed.
	my $item_width = $$specs{'txtFinalWidth'};
	my $item_height = $$specs{'txtFinalHeight'};

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = int $$specs{"txtQuantity$qty_index"};
		next if ! $qty;

		my %bestPrice;
		my @equipment = ();
		if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
			@equipment = openprint::Equipment::find( 'strid'=> $$specs{"ddmEquipment$qty_index"} );
		} else {
			@equipment = @possible_equipment;
		} # end if

		foreach my $Equipment ( @equipment ) {
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Equipment: %s Width: %s<br/>', $Equipment->name(), $Equipment->specification('Maximum Sheet Width') );

			my $imposition = new openprint::Imposition( );
			# How many can we fit in the width?
			my $imposition1 = int( $Equipment->specification('Maximum Sheet Width') / $item_width );
			my $imposition2 = int( $Equipment->specification('Maximum Sheet Width') / $item_height );
			if ( $imposition2 > $imposition1 ) {
				$imposition->rows($qty/$imposition2);
				$imposition->columns($imposition2);
				$imposition->image_orientation('Horizontal');
			} elsif ( $imposition1 ) {
				$imposition->rows($qty/$imposition1);
				$imposition->columns($imposition1);
				$imposition->image_orientation('Vertical');
			} else {
				# doesn't fit?
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf( 'Items across: ( %s x %s ) %d<br/>', $item_width, $item_height, $imposition->columns() );
			my %ServicePrice = openprint::service::get_price_object( $$specs{'ServiceType'}, undef, $Equipment );
			my %SetupPrice = openprint::service::get_price_object( $$specs{'ServiceType'}.'MakeReady', undef, $Equipment );

			my $price = $SetupPrice{'Price'};
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Setup: $%.2f<br/>', $SetupPrice{'Price'});
			if ( $ServicePrice{'units'} eq 'Per M' ) {
				my $serviceprice = ($ServicePrice{Price} * $qty)/1000;
				$price += $serviceprice;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: $%.2f %s * %f = $%.2f<br/>', @ServicePrice{'Price','units'}, $qty, $serviceprice );
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units ($ServicePrice{'units'}) for $$specs{'ServiceType'}\n";
			} # end if
			if ( $MaterialPrice{'units'} eq 'per square foot' ) {
				my $area;
				if ( $$imposition{'ImageOrientation'} eq 'Vertical' ) {
					$area = $item_height * $imposition->rows();
				} else {
					$area = $item_width * $imposition->rows();
				} # end if
				if ( $_ = $Equipment->specification('Maximum Sheet Width') ) {
					$area = ($area * $_) / 144;
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf("No Maximum Sheet Width set for %s\n", $Equipment->strid() );
				} # end if

				# have to reload price to get one with quantity discounts
				if ( my @Materials = openprint::Material::find( 'name'=>$$specs{'LaminationType'} ) ) {
					%MaterialPrice = $Materials[0]->get_price( $area, $Equipment );
				} # en if
				my $materialprice = $MaterialPrice{Price} * $area;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material: $%.2f %s * %.2f square feet = $%.2f<br/>', @MaterialPrice{'Price','units'}, $area, $materialprice );
				$price += $materialprice;
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material: unknown units: (%s)<br/>', $MaterialPrice{'units'} );
			} # end if
			if ( ( ! $bestPrice{'Price'} ) or $bestPrice{'Price'} > $price ) {
				$bestPrice{'Price'} = $price;
				$bestPrice{'Equipment'} = $Equipment;
			} # end if
		} # end foreach equipment
		$bestPrice{'Price'} = $MinimumCharge{Price} if $bestPrice{'Price'} < $MinimumCharge{Price};
		$$specs{"ddmEquipment$qty_index"} = $bestPrice{'Equipment'}->strid();
		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $bestPrice{'Price'}*(1+$$specs{"Markup$qty_index"}/100) );
		} else {
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # en dif
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $bestPrice{'Price'}/$qty );
	} # end foreach qty_index
	return 'calculated';
} # end sub calc

sub display {
	my ( $log, $dbh, $variable ) = @_;

	my @equipment = openprint::Equipment::find( 'Specifications' => {'Laminating Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'strName');
	foreach my $qty_index ( 1 .. 3 ) {	
	$$variable{'ddmEquipment'.$qty_index} = ssi::make_drop_down( [ map { $_->strid(), $_->name() } @equipment ], $$variable{'ddmEquipment'.$qty_index} );
	} # end foreach qty_index
} # end sub display


1;
__END__
