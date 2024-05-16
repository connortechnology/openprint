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
use strict;
use warnings;

use openprint::Imposition;
require openprint::Equipment;
require openprint::service;

require sql;
use vars qw( %ServicePrices %MaterialPrices %Specifications);
%ServicePrices = (
LaminationMinimumCharge => { units=>[] },
LaminationMakeReady => { units => [] },
Lamination => { units => ['per m','per hour', 'per inch'] },
);

sub ServicePriceConfiguration {
  my $name = shift;
  return $ServicePrices{$name} if $ServicePrices{$name};
  foreach my $key (keys %ServicePrices) {
    return $ServicePrices{$key} if ($name =~ /$key/i);
  }
  return undef;
}

%MaterialPrices = (
'.*Laminate.*' => { units => [ 'per square foot', 'per m square inches' ] }
);
sub MaterialPriceConfiguration {
  my $name = shift;
  return $MaterialPrices{$name} if $MaterialPrices{$name};
  foreach my $key (keys %MaterialPrices) {
    return $MaterialPrices{$key} if ($name =~ /$key/i);
  }
  return undef;
}

%Specifications = (
'Laminating Count' => { units => 'Net Sheets', 'Gross Sheets' },
  'Laminating Waste'  => { units => 'Percent' },
  'Laminating Style' => { values => [ 'Sheet','Final Pieces' ] },
  'Laminating Capable' => { values => [ 'Y'|'N' ] },
  'Laminating Sides' => { values => ['Both', 'Single'] },
  'Maximum Sheet Width' => { units => 'Inches' },
  'Maximum Sheet Length' => { units => 'Inches' },
  'Minimum Sheet Width' => { units => 'Inches' },
  'Minimum Sheet Length' => { units => 'Inches' },
  'Maximum Calliper' => { units => 'Inches' },
  'Minimum Calliper' => { units => 'Inches' },
  'Run Speed' => { units => 'inches per hour' },
);

sub SpecificationConfiguration {
  my $name = shift;
  return $Specifications{$name} if $Specifications{$name};
  return undef;
}

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
  my $sig_specs = $printing_specs;
	
	if ( (!$$specs{chkOverrideDimensions}) or ($$specs{chkOverrideDimensions} ne 'Y')) {
		@$specs{'txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	} # end if

	if ( $$specs{LaminationType} ) {
		$$specs{TypeFront} = $$specs{TypeBack} = $$specs{LaminationType};
	} # end if

	$$specs{alert} = '';
	$$specs{alert} .= 'Please select lamination type for front.<br/>' if ! $$specs{TypeFront};
	$$specs{alert} .= 'Please select lamination type for back.<br/>' if ! $$specs{TypeBack};
	$$specs{alert} .= 'Please enter object width.<br/>' if ! $$specs{txtFinalWidth};
	$$specs{alert} .= 'Please enter object height.<br/>' if ! $$specs{txtFinalHeight};

	if ( $$specs{alert} ) {
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			$$specs{'txtPrice'.$qty_index} = '';
			$$specs{'MPrice'.$qty_index} = '';
			$$specs{'txtUnitPrice'.$qty_index} = '';
		} # end foreach qty_index
		return $$specs{Status} = 'uncalculated';
	} # end if

  my %MinimumCharge = openprint::service::get_price_object( $$specs{ServiceType}.'MinimumCharge', undef, undef );
  $MinimumCharge{Price} ||= 0;

  my @possible_equipment;
  my @all_equipment = openprint::Equipment->find(
    Specifications => {
      'Laminating Capable'=>'Y'
    },
    'useinestimating'=>1,'order'=>'lower(strName)');

  if ( ! @all_equipment ) {
    $$specs{alert} = 'We have no laminating equipment.';
    return $$specs{Status} = 'uncalculated';
  } # end if

  my $error = '';
  foreach my $Equipment ( @all_equipment ) {
    my $style = $Equipment->specification('Laminating Style');

    if ((!$style) or ($style ne 'Sheet')) {
      if ( 
        (my $reason1 = $Equipment->fits( $$specs{txtFinalWidth} ) ) and
        (my $reason2 = $Equipment->fits( $$specs{txtFinalHeight} ) ) 
      ) {
        $error .= 'For ' . $Equipment->name() . ': '. $reason1  . '<br/>' . $reason2;
      } else {
        push @possible_equipment, $Equipment
      } # end if
    } else {
      push @possible_equipment, $Equipment
    }
  } # end foreach

	if ( ! @possible_equipment ) {
		$$specs{alert} = "Our equipment cannot run this project, for the following reasons:\n$error\n Please only print flat sheets and contact another bindery.";
		return $$specs{Status} = 'uncalculated';
	} # end if

	# So we can do multiple items at once, as many as will fit in the width of the laminator.
  # We need a certain amount of space between the items.  I suspect that this should be an 
  # input, not a fixed value, but for now we will make it fixed.
	my $item_width = $$specs{txtFinalWidth};
	my $item_height = $$specs{txtFinalHeight};

	my $MakeReady = openprint::Service->find_one( name=>$$specs{ServiceType}.'MakeReady' );
	my $Service = openprint::Service->find_one( name=>$$specs{ServiceType} );

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g if $$specs{"Markup$qty_index"};
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g if $$specs{"txtPrice$qty_index"};
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
    $$specs{'hdnBreakdown'.$qty_index} .= 'Signature ' . $$sig_specs{SignatureIndex} . 'Printed: ' .openprint::service::summary( $Project, $sigs[0], $qty_index ).'<br/>';
		my $qty = int $$specs{"txtQuantity$qty_index"};
		next if ! $qty;

		my %bestPrice = (Price=>0);
		my @equipment = ();
		if ($$specs{"chkOverrideEquipment$qty_index"} and ($$specs{"chkOverrideEquipment$qty_index"} eq 'Y' and $$specs{"ddmEquipment$qty_index"})) {
			@equipment = openprint::Equipment->find(id=> $$specs{"ddmEquipment$qty_index"} );
		} else {
			@equipment = @possible_equipment;
		} # end if
    if (!@equipment) {
      $$specs{alert} .= 'No equipment found for qty '.$qty_index.'.<br/>';
    }

		foreach my $Equipment ( @equipment ) {
      my $sides = $Equipment->specification('Laminating Sides') || '';
			if ((( $$specs{TypeFront} eq 'None' ) or ( $$specs{TypeBack} eq 'None' )) and ( $sides eq 'Both' ) ) {
				if ( $$specs{"chkOverrideEquipment$qty_index"} and ($$specs{"chkOverrideEquipment$qty_index"} eq 'Y')) {
					$$specs{alert} .= 'The chosen laminator must do both sides.  You have chosen no lamination for one of the sides.<br/>';
				} # end if
				next;
			} # end if
			my $maximum_sheet_width = $Equipment->specification('Maximum Sheet Width');
			my $maximum_sheet_length= $Equipment->specification('Maximum Sheet Length');
			my $laminate_width = $Equipment->specification('Laminate Width');
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Equipment: %s max Width: %s Length: %s<br/>',
          $Equipment->name(), $maximum_sheet_width, $maximum_sheet_length);
      my $sheets = 0;

			my $length;
      my $imposition = new openprint::Imposition();
      my $style = $Equipment->specification('Laminating Style') || '';
      if ($style ne 'Sheet') {
        # How many can we fit in the width?
        my $imposition1 = int( $maximum_sheet_width / $item_width );
        my $imposition2 = int( $maximum_sheet_width / $item_height );
        if ( $imposition2 > $imposition1 ) {
          $imposition->rows($qty/$imposition2);
          $imposition->columns($imposition2);
          $imposition->image_orientation(openprint::Imposition::Horizontal);
        } elsif ( $imposition1 ) {
          $imposition->rows($qty/$imposition1);
          $imposition->columns($imposition1);
          $imposition->image_orientation(openprint::Imposition::Vertical);
        }
        if ( $$imposition{image_orientation} == openprint::Imposition::Vertical ) {
          $length = $item_height * $imposition->rows();
        } else {
          $length = $item_width * $imposition->rows();
        } # end if
        $$specs{'hdnBreakdown'.$qty_index} .= sprintf('Items across: ( %s x %s ) %d style:%s<br/>', $item_width, $item_height, $imposition->columns(), $style );
        $sheets = $qty;
      } else {
        $imposition->load( $sig_specs, $qty_index, $Project );
        $_ = equipment_fits($Equipment, $imposition, $imposition->Paper());
        if ($_) {
          $$specs{'hdnBreakdown'.$qty_index} .= 'Doesn\'t fit.'.$_.'<br/>';
          next;
        } # end if
        if ($imposition->sheet_width() > $maximum_sheet_width) {
          $length = $imposition->sheet_width();
        } elsif ($imposition->sheet_height() > $maximum_sheet_width) {
          $length = $imposition->sheet_height();
        } else {
          # They both fit, use the shorter
          $length = ($imposition->sheet_width() > $imposition->sheet_height ? $imposition->sheet_height() : $imposition->sheet_width());
        }
        my $count = $Equipment->specification('Laminating Count');
        if ($count eq 'Net Sheets') {
          $sheets = $$imposition{net_sheets};
        } else {
          $sheets = $$imposition{impressions} ? $$imposition{impressions} : $$imposition{net_sheets};
        }
        $sheets = $qty if ! $sheets;
      }
      my $waste = $Equipment->Specification('Laminating Waste');
      if ($waste) {
        if ($$waste{units} eq 'percent') {
          $sheets *= 1+($$waste{value}/100);
        }
      }

			my $area;
			if ($laminate_width) {
				$area = $length * $laminate_width * $sheets;
      } elsif ($maximum_sheet_width) {
				$area = $length * $maximum_sheet_width * $sheets;
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('No Maximum Sheet Width set for %s<br/>', $Equipment->strid() );
				$area = $length*$sheets;
			} # end if
      $$specs{'hdnBreakdown'.$qty_index} .= 'Using '.$length.'" x '.($laminate_width?$laminate_width:$maximum_sheet_width).'" laminate width * '.$sheets.' sheets = '.$area.' square inches<br/>';

			my %SetupPrice = $MakeReady->get_price(undef, $Equipment ) if $MakeReady;
			my $price = $SetupPrice{Price};
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Setup: $%.2f<br/>', $SetupPrice{Price});

			my $MPrice = 0;

			my %ServicePrice = $Service->get_price( undef, $Equipment ) if $Service;
			if ( %ServicePrice ) {
				if ( $ServicePrice{units} eq 'per m' ) {
					my $serviceprice = ($ServicePrice{Price} * $qty)/1000;
					$price += $serviceprice;
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: $%.2f %s * %f = $%.2f<br/>', @ServicePrice{'Price','units'}, $qty, $serviceprice );
					$MPrice += $serviceprice;
        } elsif ( $ServicePrice{units} eq 'per inch' ) {
          my $linear_length = Math::Round::nearest(0.01, $length * $sheets);
          #$$specs{'hdnBreakdown'.$qty_index} .= "Linear length $length * $sheets = $linear_length inches<br/>";
          $ServicePrice{Total} = Math::Round::nearest( 0.01, $ServicePrice{Price} * $linear_length );
          $$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: $%1$.2f %2$s * %4$d inches = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $linear_length);
          $MPrice += Math::Round::nearest( 0.01, $ServicePrice{Price} * ( $length * ( 1000 / $$imposition{imposition} ) ));

				} elsif ( $ServicePrice{units} eq '/Hr' or $ServicePrice{units} eq 'per hour') {
					my $inches_per_hour;
					my $Speed = $Equipment->Specification( 'Run Speed' ) ;
					if ( $Speed ) {
						if ( lc $$Speed{units} eq 'inches per hour' ) {
							$inches_per_hour = $$Speed{value};
						} else {
							$$specs{'hdnBreakdown'.$qty_index} .= "Unknown speed units ($$Speed{units}<br/>";
							$inches_per_hour = 720;
						} # end if
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= 'No speed set<br/>';
						$inches_per_hour = 720;
					} # end if


          if ($style ne 'Sheet' ) {
            my $hours = Math::Round::nearest( 0.01, $length * ( $qty / $$imposition{imposition} ) / $inches_per_hour );
            $ServicePrice{Total} = Math::Round::nearest( 0.01, $ServicePrice{Price} * $hours );
            if ($sides eq 'Single' and $$specs{TypeFront} ne 'None' and $$specs{TypeBack} ne 'None') {
            $$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: Front $%1$.2f %2$s * %4$.2fhours = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $hours);
            $$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: Back $%1$.2f %2$s * %4$.2fhours = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $hours);
            $ServicePrice{Total} *= 2;
            $ServicePrice{Price} *= 2;
            } else {
            $$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: Both sides $%1$.2f %4$s * %2$.2fhours = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $hours);
            }
            $MPrice += Math::Round::nearest( 0.01, $ServicePrice{Price} * ( $length * ( 1000 / $$imposition{imposition} ) ) / $inches_per_hour );
          } else {
            my $hours = Math::Round::nearest(0.01, $length * $sheets / $inches_per_hour);
            $$specs{'hdnBreakdown'.$qty_index} .= "Runtime = length $length * $sheets / $inches_per_hour<br/>";
            $ServicePrice{Total} = Math::Round::nearest( 0.01, $ServicePrice{Price} * $hours );
            if ($sides eq 'Single' and $$specs{TypeFront} ne 'None' and $$specs{TypeBack} ne 'None') {
              $$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: Front $%1$.2f %2$s * %4$.2fhours = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $hours);
              $$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: Back $%1$.2f %2$s * %4$.2fhours = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $hours);
              $ServicePrice{Total} *= 2;
            $ServicePrice{Price} *= 2;
            } else {
              $$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service: Both sides: $%1$.2f %2$s * %4$.2fhours = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $hours);
            }
            $MPrice += Math::Round::nearest( 0.01, $ServicePrice{Price} * ( $length * ( 1000 / $$imposition{imposition} ) ) / $inches_per_hour );
          }
					$price += $ServicePrice{Total};
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units ($ServicePrice{units}) for $$specs{ServiceType}<br/>";
				} # end if
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= "No Service price for $$specs{ServiceType}<br/>";
			} # end if
			if ( $$specs{TypeFront} ne 'None' ) {
				my $FrontMaterialPrice;
				if ( my $FrontMaterial = openprint::Material->find_one(name=>$$specs{TypeFront} ) ) {
					$FrontMaterialPrice = $FrontMaterial->get_Price( $area, $Equipment );
					if ( ! $FrontMaterialPrice ) {
						if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
							$$specs{alert} .= "There is no price for $$FrontMaterial{description} on $$Equipment{name}.<br/>";
						} # end if

						next;
					} # end if
					if ( $$FrontMaterialPrice{units} eq 'per square foot' ) {
						$$FrontMaterialPrice{Total} = $$FrontMaterialPrice{Price} * $area / 144;
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material on Front: $%1$.2f %2$s * %4$.2f square feet = $%3$.2f<br/>', @$FrontMaterialPrice{'Price','units','Total'}, $area/144 );
					} elsif ( $$FrontMaterialPrice{units} eq 'per m square inches' ) {
						$$FrontMaterialPrice{Total} = $$FrontMaterialPrice{Price} * $area / 1000;
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material on Front: $%1$.2f %2$s * %4$.2f inches = $%3$.2f<br/>', @$FrontMaterialPrice{'Price','units','Total'}, $area/1000 );
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material on Front: unknown units: (%s)<br/>', $FrontMaterialPrice->to_string() );
					} # end if
          $price += $$FrontMaterialPrice{Total};
          $MPrice += ( 1000 / $imposition->imposition() ) * $$FrontMaterialPrice{Total};
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('No Material found for Front: (%s)<br/>', $$specs{TypeFront} );
				} # end if Material Found
			} # end if TypeFront

			if ( $$specs{TypeBack} ne 'None' ) {
				my %BackMaterialPrice;
				if ( my $BackMaterial = openprint::Material->find_one(name=>$$specs{TypeBack} ) ) {
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
					} elsif ( $BackMaterialPrice{units} eq 'per m square inches' ) {
						$BackMaterialPrice{Total} = $BackMaterialPrice{Price} * $area / 1000;
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material on Back: $%1$.2f %2$s * %4$.2f square inches = $%3$.2f<br/>', @BackMaterialPrice{'Price','units','Total'}, $area/1000 );
					} else {
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material on Front: unknown units: (%s)<br/>', $BackMaterialPrice{units} );
					} # end if
          $price += $BackMaterialPrice{Total};
          $MPrice += ( 1000 / $imposition->imposition() ) * $BackMaterialPrice{Total};
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('No Material found for Back: (%s)<br/>', $$specs{TypeBack} );
				} # end if Material Found
			} # end if TypeFront

			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Total: $%.2f<br/><br/>', $price );

			if ( ( ! $bestPrice{Price} ) or $bestPrice{Price} > $price ) {
				$bestPrice{Price} = $price;
				$bestPrice{MPrice} = $MPrice;
				$bestPrice{Equipment} = $Equipment;
			} # end if
		} # end foreach equipment

		if ( %bestPrice and ($bestPrice{Price} < $MinimumCharge{Price})) {
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('<br/>Using minimum charge: $%.2f<br/>', $MinimumCharge{Price} );
			$bestPrice{Price} = $MinimumCharge{Price};
		} # end if

		$$specs{"ddmEquipment$qty_index"} = $bestPrice{Equipment}->id() if $bestPrice{Equipment};
		if ((!$$specs{"OverridePrice$qty_index"}) or ( $$specs{"OverridePrice$qty_index"} ne 'Y')) {
      $bestPrice{UnitPrice} = $bestPrice{Price}/$qty;
			if ( $$specs{"Markup$qty_index"} ) {
				$bestPrice{Price} *= 1+$$specs{"Markup$qty_index"}/100;
				$bestPrice{UnitPrice} *= 1+$$specs{"Markup$qty_index"}/100;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Using %s% markup = $%.2f<br/>', $$specs{"Markup$qty_index"}, $bestPrice{Price} );
			}
			if ( $Project->markup() ) {
				$bestPrice{Price} *= 1+$Project->markup()/100;
				$bestPrice{UnitPrice} *= 1+$Project->markup()/100;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Using %s% project markup = $%.2f<br/>', $Project->markup(), $bestPrice{Price} );
			} 
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $bestPrice{Price} );
      $$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{UnitPriceFormat}, $bestPrice{UnitPrice} );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $$specs{"txtPrice$qty_index"} );
			$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $$specs{"txtUnitPrice$qty_index"} );
		} # en dif
    $bestPrice{MPrice} *= (1+$Project->markup()/100) if $Project->markup();
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{UnitPriceFormat}, $bestPrice{MPrice} );
	} # end foreach qty_index
	return $$specs{Status} = 'calculated';
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
	my ( $Project, $service_index, $specs, $qty_index ) = @_;
  if ($qty_index) {
    return 'on '.new openprint::Equipment($$specs{'ddmEquipment'.$qty_index})->name();
  }
  return $$specs{TypeFront}.' on front, '.$$specs{TypeBack}.' on back';
} # end sub summary

sub save {
} # end sub save

sub equipment_fits {
  my ( $Equipment, $I, $Stock ) = @_;
  if ( ( $_ = $Equipment->fits( $I->sheet_width(), $I->sheet_height() ) ) and ( $_ = $Equipment->fits( $I->layout_width(), $I->layout_height() ) ) ) {
    return $_;
  }
  if ( my $min_calliper = $Equipment->specification( 'Minimum Calliper')) {
    if ( $min_calliper > $$Stock{calliper} ) {
      return "Calliper too thin stock calliper $$Stock{calliper} < minimum($min_calliper).";
    }
  }
  if ( my $max_calliper = $Equipment->specification('Maximum Calliper')) {
    if ( $max_calliper < $$Stock{calliper} ) {
      return "Calliper too thick stock calliper $$Stock{calliper} > maximum($max_calliper).";
    }
  }
  return;
}

1;
__END__
