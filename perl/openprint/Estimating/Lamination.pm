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

require openprint::Equipment;
require openprint::service;

require sql;

my @variables = (
	'txtFinalWidth','txtFinalHeight','chkOverrideDimensions',
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1', 'Markup2', 'Markup3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
	'MPrice1', 'MPrice2', 'MPrice3',
	'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
	'chkOverrideEquipment1', 'chkOverrideEquipment2', 'chkOverrideEquipment3',
	'TypeFront','TypeBack',
);

sub variables {
	return @variables;
} # end sub variables

my @outputs = (
	'txtFinalWidth','txtFinalHeight',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'MPrice1', 'MPrice2', 'MPrice3',
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
	my $services = $Project->services();

	my @sigs = $Project->signatures();

	my $printing_specs = openprint::service::get_specs_ref( $project_index, $sigs[0] );
	
	if ( $$specs{'chkOverrideDimensions'} ne 'Y' ) {
		@$specs{'txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	} # end if

	if ( $$specs{LaminationType} ) {
		$$specs{TypeFront} = $$specs{TypeBack} = $$specs{LaminationType};
	} # end if

	$$specs{alert} = '';
	$$specs{alert} .= 'Please select lamination type for front.<br/>' if ! $$specs{'TypeFront'};
	$$specs{alert} .= 'Please select lamination type for back.<br/>' if ! $$specs{'TypeBack'};
	$$specs{alert} .= 'Please enter object width.<br/>' if ! $$specs{'txtFinalWidth'};
	$$specs{alert} .= 'Please enter object height.<br/>' if ! $$specs{'txtFinalHeight'};

	if ( $$specs{alert} ) {
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			$$specs{'txtPrice'.$qty_index} = '';
			$$specs{'MPrice'.$qty_index} = '';
			$$specs{'txtUnitPrice'.$qty_index} = '';
		} # end foreach qty_index
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my %MinimumCharge = openprint::service::get_price_object( $$specs{'ServiceType'}.'MinimumCharge', undef, undef );

   my @possible_equipment;
   my @all_equipment = openprint::Equipment->find( 'Specifications' => {'Laminating Capable'=>'Y'}, 'useinestimating'=>1,'order'=>'lower(strName)');

    if ( ! @all_equipment ) {
      	$$specs{'alert'} = 'We have no laminating equipment.';
		return $$specs{'Status'} = 'uncalculated';
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
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	# So we can do multiple items at once, as many as will fit in the wiwdth of the laminator.  We need a certain amount of space between the items.  I suspect that this should be an input, not a fixed value, but for now we will make it fixed.
	my $item_width = $$specs{'txtFinalWidth'};
	my $item_height = $$specs{'txtFinalHeight'};

	my $MakeReady = openprint::Service->find_one( name=>$$specs{ServiceType}.'MakeReady' );
	my $Service = openprint::Service->find_one( name=>$$specs{ServiceType} );

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = int $$specs{"txtQuantity$qty_index"};
		next if ! $qty;

		my %bestPrice;
		my @equipment = ();
		if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
			@equipment = openprint::Equipment->find( 'strid'=> $$specs{"ddmEquipment$qty_index"} );
		} else {
			@equipment = @possible_equipment;
		} # end if

		foreach my $Equipment ( @equipment ) {
			if ( ( $$specs{TypeFront} eq 'None' ) or ( $$specs{TypeBack} eq 'None' ) and ( $Equipment->specification('Laminating Sides') eq 'Both' ) ) {
				if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
					$$specs{alert} .= 'The chosen laminator must do both sides.  You have chosen no lamination for one of the sides.<br/>';
				} # end if
				next;
			} # end if
			my $maximum_sheet_width = $Equipment->specification('Maximum Sheet Width');
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Equipment: %s Width: %s<br/>', $Equipment->name(), $maximum_sheet_width );

			my $imposition = new openprint::Imposition( );
			# How many can we fit in the width?
			my $imposition1 = int( $maximum_sheet_width / $item_width );
			my $imposition2 = int( $maximum_sheet_width / $item_height );
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
			my $area;

			my $length;
			if ( $$imposition{'ImageOrientation'} eq 'Vertical' ) {
				$length = $item_height * $imposition->rows();
			} else {
				$length = $item_width * $imposition->rows();
			} # end if
			if ( $maximum_sheet_width ) {
				$area = $length * $maximum_sheet_width;
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf("No Maximum Sheet Width set for %s<br/>", $Equipment->strid() );
				$area = $length;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf( 'Items across: ( %s x %s ) %d<br/>', $item_width, $item_height, $imposition->columns() );
			my %SetupPrice = $MakeReady->get_price( undef, $Equipment ) if $MakeReady;
			my $price = $SetupPrice{'Price'};
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Setup: $%.2f<br/>', $SetupPrice{'Price'});

			my $MPrice = 0;

			my %ServicePrice = $Service->get_price( undef, $Equipment ) if $Service;
			if ( %ServicePrice ) {
				if ( $ServicePrice{'units'} eq 'per m' ) {
					my $serviceprice = ($ServicePrice{'Price'} * $qty)/1000;
					$price += $serviceprice;
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: $%.2f %s * %f = $%.2f<br/>', @ServicePrice{'Price','units'}, $qty, $serviceprice );
					$MPrice += $serviceprice;
				} elsif ( $ServicePrice{units} eq '/Hr' ) {
					my $inches_per_hour;
					my $Speed = $Equipment->Specification( 'Speed' ) ;
					if ( $Speed ) {
						if ( $$Speed{units} eq 'Inches Per Hour' ) {
							$inches_per_hour = $$Speed{value};
						} else {
							$$specs{'hdnBreakdown'.$qty_index} .= "Unknown speed units ($$Speed{units}<br/>";
							$inches_per_hour = 720;
						} # end if
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= "No speed set<br/>";
						$inches_per_hour = 720;
					} # end if
					my $hours = Math::Round::nearest( 0.01, $length * ( $qty / $$imposition{imposition} ) / $inches_per_hour );
						
					my $serviceprice = $ServicePrice{Total} = Math::Round::nearest( 0.01, $ServicePrice{Price} * $hours );
					$price += $serviceprice;
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: $%.2f %s * %.2fhours = $%.2f<br/>', @ServicePrice{'Price','units'}, $hours, $serviceprice );
					$MPrice += Math::Round::nearest( 0.01, $ServicePrice{Price} * ( $length * ( 1000 / $$imposition{imposition} ) ) / $inches_per_hour );
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units ($ServicePrice{'units'}) for $$specs{'ServiceType'}<br/>";
				} # end if
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= "No Service price for $$specs{'ServiceType'}<br/>";
			} # end if
			if ( $$specs{TypeFront} ne 'None' ) {
				my %FrontMaterialPrice;
				if ( my $FrontMaterial = openprint::Material->find_one( 'name'=>$$specs{TypeFront} ) ) {
					%FrontMaterialPrice = $FrontMaterial->get_price( $area, $Equipment );
					if ( ! %FrontMaterialPrice ) {
						if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
							$$specs{alert} .= "There is no price for $$FrontMaterial{description} on $$Equipment{name}.<br/>";
						} # end if

						next;
					} # end if
					if ( $FrontMaterialPrice{units} eq 'per square foot' ) {
						$FrontMaterialPrice{Total} = $FrontMaterialPrice{Price} * $area / 144;
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material on Front: $%1$.2f %2$s * %4$.2f square feet = $%3$.2f<br/>', @FrontMaterialPrice{'Price','units','Total'}, $area/144 );
						$price += $FrontMaterialPrice{Total};
						$MPrice += ( 1000 / $imposition->imposition() ) * $FrontMaterialPrice{Total};
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material on Front: unknown units: (%s)<br/>', $FrontMaterialPrice{units} );
					} # end if
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('No Material found for Front: (%s)<br/>', $$specs{TypeFront} );
				} # end if Material Found
			} # end if TypeFront
			if ( $$specs{TypeBack} ne 'None' ) {
				my %BackMaterialPrice;
				if ( my $BackMaterial = openprint::Material->find_one( 'name'=>$$specs{TypeBack} ) ) {
					%BackMaterialPrice = $BackMaterial->get_price( $area, $Equipment );
					if ( ! %BackMaterialPrice ) {
						if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
							$$specs{alert} .= "There is no price for $$BackMaterial{description} on $$Equipment{name}.<br/>";
						} # end if
						next;
					} # end if
					if ( $BackMaterialPrice{units} eq 'per square foot' ) {
						$BackMaterialPrice{Total} = $BackMaterialPrice{Price} * $area / 144;
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material on Back: $%1$.2f %2$s * %4$.2f square feet = $%3$.2f<br/>', @BackMaterialPrice{'Price','units','Total'}, $area/144 );
						$price += $BackMaterialPrice{Total};
						$MPrice += ( 1000 / $imposition->imposition() ) * $BackMaterialPrice{Total};
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material on Front: unknown units: (%s)<br/>', $BackMaterialPrice{units} );
					} # end if
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('No Material found for Back: (%s)<br/>', $$specs{TypeBack} );
				} # end if Material Found
			} # end if TypeFront

			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Total: %.2f<br/><br/>', $price );

			if ( ( ! $bestPrice{'Price'} ) or $bestPrice{'Price'} > $price ) {
				$bestPrice{'Price'} = $price;
				$bestPrice{'MPrice'} = $MPrice;
				$bestPrice{'Equipment'} = $Equipment;
			} # end if
		} # end foreach equipment

		if ( $bestPrice{'Price'} < $MinimumCharge{Price} ) {
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('<br/>Using minimum charge: $%.2f<br/>', $MinimumCharge{Price} );
			$bestPrice{'Price'} = $MinimumCharge{Price};
		} # end if
		$$specs{"ddmEquipment$qty_index"} = $bestPrice{Equipment}->strid() if $bestPrice{Equipment};
		if ( $$specs{"OverridePrice$qty_index"} ne 'Y' ) {
			if ( $$specs{"Markup$qty_index"} ) {
				$bestPrice{'Price'} *= 1+$$specs{"Markup$qty_index"}/100;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Using %s% markup = $%.2f<br/>', $$specs{"Markup$qty_index"}, $bestPrice{Price} );
			}
			if ( $Project->markup() ) {
				$bestPrice{'Price'} *= 1+$Project->markup()/100;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Using %s% project markup = $%.2f<br/>', $Project->markup(), $bestPrice{Price} );
			} 
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $bestPrice{Price} );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # en dif
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, ( $bestPrice{'Price'}/$qty ) * (1+$Project->markup()/100) );
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $bestPrice{'MPrice'} * (1+$Project->markup()/100) );
	} # end foreach qty_index
	return $$specs{'Status'} = 'calculated';
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;
	my $Project = new openprint::Project( $project_index );

	my @equipment = openprint::Equipment->find( 'Specifications' => {'Laminating Capable'=>'Y'}, 'useinestimating'=>1,'order'=>'strName');
	foreach my $qty_index ( $Project->quantity_indexes() ) {	
	$$variable{'ddmEquipment'.$qty_index} = ssi::make_drop_down( [ map { $_->strid(), $_->name() } @equipment ], $$variable{'ddmEquipment'.$qty_index} );
	} # end foreach qty_index
} # end sub display

sub summary {
} # end sub summary

sub save {
} # end sub save

1;
__END__
