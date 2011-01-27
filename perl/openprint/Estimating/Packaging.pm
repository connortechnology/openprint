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

package openprint::Estimating::Packaging;
use strict;
use POSIX qw(ceil);

require openprint::service;

require sql;

my @variables = (
	'txtItemsPerPackage','AccurateCount','bands_per_package',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'Markup1','Markup2','Markup3',
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'txtPackageQuantity1',
	'txtPackageQuantity2',
	'txtPackageQuantity3',
	'rdbCardboardBacking',
	'type_id',
);
sub variables {
    return @variables;
}

my @no_outputs = (
	'OverridePrice1', 'OverridePrice2', 'OverridePrice3',
	'Markup1','Markup2','Markup3',
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'txtItemsPerPackage','AccurateCount',
	'rdbCardboardBacking',
);

sub no_outputs {
	return @no_outputs;
}

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	if ( ! $$services{''} ) {
		$$specs{'alert'} .= 'Unable to find project service.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	my $ServiceType = $Project->ServiceType( $service_index );
	my $status = 'calculated';
	my $printing_specs = openprint::service::get_specs_ref( $project_index, $$services{''}[0] );

	$$specs{'txtItemsPerPackage'} = int($$specs{'txtItemsPerPackage'});
	if ( ! $$specs{'txtItemsPerPackage'} ) {	# a zero value is still calculated, just with a zero price.d
		if ( $ServiceType->name() eq 'Bundling' ) {
			$$specs{'alert'} .= 'Please enter the # of items in each bundle';
		} elsif ( $ServiceType->name() eq 'ShrinkWrap' ) {
			$$specs{'alert'} .= 'Please enter the # of items in each wrap';
		} else {
			$$specs{'alert'} .= 'Please enter the # of items in each ' . $ServiceType->name();
		} # end if
        return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( ! $$specs{'rdbCardboardBacking'} ) {
        $$specs{'alert'} = 'Please select whether you need cardboard backing.';
        return $$specs{'Status'} = 'uncalculated';
    } # end if

	$$specs{'bands_per_package'} =~ s/[^\d\.]//g;
	my $makeReady = openprint::service::get_price( $ServiceType->name().'MakeReady', undef, undef );
	my $minCharge = openprint::service::get_price( $ServiceType->name().'Minimum', undef, undef );

	foreach my $qty_index ( $Project->quantity_indexes() ) {

		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{'txtPressSheetComboItems'} ? $$specs{'txtQuantity'.$qty_index} * $$specs{'txtPressSheetComboItems'} : $$specs{'txtQuantity'.$qty_index};
		next if ! $qty;

		my $package_qty = $$specs{'txtItemsPerPackage'} ? ceil( $qty/$$specs{'txtItemsPerPackage'}) : 0;

		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Minimum Charge: $%.2f<br/>', $minCharge );
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Makeready: $%.2f<br/>', $makeReady );
		my $price = 0;
		my $unitPrice = 0;
		my %ServicePrice = openprint::service::get_price_object( $ServiceType->name(), $qty, undef );
		if ( %ServicePrice ) {
			if ( lc $ServicePrice{'units'} eq 'per m' ) {
				$ServicePrice{'Total'} = $ServicePrice{'Price'} * $qty / 1000;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('ServicePrice %1$.2f%2$s * %4$d = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $qty );
			} elsif ( lc $ServicePrice{'units'} eq 'each' ) {
				$ServicePrice{'Total'} = $ServicePrice{'Price'} * $qty;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('ServicePrice %1$.2f%2$s * %4$d = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $qty );
			} elsif ( lc $ServicePrice{'units'} eq 'per bundle' ) {
				$ServicePrice{'Total'} = $ServicePrice{'Price'} * $package_qty;
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('ServicePrice %1$.2f%2$s * %4$d = $%3$.2f<br/>', @ServicePrice{'Price','units','Total'}, $package_qty );
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('No units set for %s (%s)<br/>', $ServiceType->name(), $ServicePrice{'units'} );
			} # end if
			$unitPrice += $ServicePrice{'Total'};
		} # end if
		$price = $unitPrice + $makeReady;

		if ( $$specs{'rdbCardboardBacking'} eq 'Y' ) {

			if ( my @Materials = openprint::Material->find('name'=>'CardboardBacking') ) {
				my %CardboardPrice = $Materials[0]->get_price( $package_qty, undef );
				if ( $CardboardPrice{'units'} eq 'Per Square Inch' ) {
					$CardboardPrice{'Total'} = $CardboardPrice{'Price'} * $$printing_specs{'txtFinalWidth'} * $$printing_specs{'txtFinalHeight'};
				} elsif ( $CardboardPrice{'units'} eq 'Per Square Foot' ) {
					$CardboardPrice{'Total'} = $CardboardPrice{'Price'} * ($$printing_specs{'txtFinalWidth'} * $$printing_specs{'txtFinalHeight'}/144);
				} elsif ( $CardboardPrice{'units'} eq 'Per Pad' ) {
					$CardboardPrice{'Total'} = $CardboardPrice{'Price'};
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Cardboard Price: $%.2f %s * %s x %s = $%.2f per package = %.2f total<br/>',@CardboardPrice{'Price','units'}, @$printing_specs{'txtFinalWidth','txtFinalHeight'}, $CardboardPrice{'Total'}, $CardboardPrice{'Total'}*$package_qty );
				$price += $CardboardPrice{'Total'} * $package_qty;
			} # end if
		} # end if
		if ( my @Materials = openprint::Material->find('category'=>$ServiceType->name()) ) {
			if ( ! $$specs{'type_id'} ) {
				$$specs{'alert'} .= 'Please select the type of ' . $ServiceType->name() . '<br/>';
				$status = 'uncalculated';
			} else {
				my $Material = new openprint::Material( $$specs{'type_id'} );
				my %MaterialPrice = $Material->get_price( $package_qty );

				my $material_qty = $package_qty;
				$material_qty *= $$specs{'bands_per_package'} if $$specs{'bands_per_package'};
				if ( lc $MaterialPrice{units} eq 'per m' ) {
					$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $material_qty / 1000;
				} elsif ( lc $MaterialPrice{units} eq 'each' ) {
					$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $material_qty;
				} elsif ( lc $MaterialPrice{units} eq 'per inch' ) {
					$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $$printing_specs{'txtFinalWidth'} * $$printing_specs{'txtFinalHeight'} * $material_qty;
				} elsif ( lc $MaterialPrice{units} eq 'per foot' ) {
					$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $$printing_specs{'txtFinalWidth'} * $$printing_specs{'txtFinalHeight'} * $material_qty / 144;
				} # end if
				$price += $MaterialPrice{'Total'};
				$unitPrice += $MaterialPrice{'Total'};
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Material Price: $%1$.2f%2$s * %4$d packages * %5$d per package = $%3$.2f<br/>',@MaterialPrice{'Price','units','Total'}, $package_qty, $$specs{'bands_per_package'} );
			} # end if
		} # end if Materials
		$price = $minCharge if $price < $minCharge;

		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Total: $%.2f<br/>',$price );
		$$specs{'txtPackageQuantity'.$qty_index} = $package_qty;
		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price*(1+$$specs{"Markup$qty_index"}/100)*(1+$Project->markup()/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # endif
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, ( $unitPrice/$qty ) * (1+$Project->markup()/100) );
	} # end foreach

	return $$specs{'Status'} = $status;
} # end sub calc

sub summary {
    my ( $Project, $service_id, $specs, $qty_index ) = @_;
    $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;
    my $text = '';
    if ( $qty_index ) {
        $text .= $$specs{'txtPackageQuantity'.$qty_index};
        if ( $$specs{'ServiceType'} =~ /Wrap/i ) {
            $text .= ' wrap' . ($$specs{'txtPackageQuantity'.$qty_index} > 1 ? 's' : '');
        } elsif ( $$specs{'ServiceType'} =~ /Bundling/i ) {
            $text .= ' bundle' . ($$specs{'txtPackageQuantity'.$qty_index} > 1 ? 's' : '');
        } elsif ( $$specs{'ServiceType'} =~ /Banding/i ) {
            $text .= ' bundle' . ($$specs{'txtPackageQuantity'.$qty_index} > 1 ? 's' : '');
        } # end if
    } else {
        $text .= $$specs{'txtItemsPerPackage'} . ' items';
        if ( $$specs{'ServiceType'} =~ /Wrap/i ) {
            $text .= ' per wrap';
        } elsif ( $$specs{'ServiceType'} =~ /Bundling/i ) {
            $text .= ' per bundle';
        } elsif ( $$specs{'ServiceType'} =~ /Banding/i ) {
            $text .= ' per band';
			$text .= sprintf(' %d bands each', $$specs{'bands_per_package'} ) if $$specs{'bands_per_package'};
        } # end if
        $text .= $$specs{'rdbCardboardBacking'} eq 'Y' ? ' with cardboard backing.' : '';
    } # end if
    return $text;
} # end sub summary

sub save {
	my ( $project_index, $service_index, $param ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	if ( ($$param{'AccurateCount'} eq 'Y' ) and ! $$services{'Counting'} ) {
		openprint::print_project::insert_service( $openprint::log, $openprint::dbh, $project_index, 'Counting' );
	} # end if
} # end sub save

1;
__END__
