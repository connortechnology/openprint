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
	'txtItemsPerPackage',
	'txtQuantity1',
	'txtPrice1',
	'txtQuantity2',
	'txtPrice2',
	'txtQuantity3',
	'txtPrice3',
	'txtPackageQuantity1',
	'txtPackageQuantity2',
	'txtPackageQuantity3',
	'rdbCardboardBacking',
);
sub variables {
    return @variables;
}

my @no_outputs = (
	'txtQuantity1','txtQuantity2','txtQuantity3',
	'txtItemsPerPackage',
	'rdbCardboardBacking',
);

sub no_outputs {
	return @no_outputs;
}

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();
	if ( ! $services{''} ) {
		$$specs{'alert'} .= 'Unable to find project service.<br/>';
		return 'uncalculated';
	} # end if
	my $status = 'calculated';

	$$specs{'txtItemsPerPackage'} = int($$specs{'txtItemsPerPackage'});
	if ( ! $$specs{'txtItemsPerPackage'} ) {	# a zero value is still calculated, just with a zero price.d
		if ( $$specs{'ServiceType'} eq 'Bundling' ) {
			$$specs{'alert'} .= 'Please enter the # of items in each bundle';
		} else {
			$$specs{'alert'} .= 'Please enter the # of items in each ' . $$specs{'ServiceType'};
		} # end if
        return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( ! $$specs{'rdbCardboardBacking'} ) {
        $$specs{'alert'} = 'Please select whether you need cardboard backing.';
        return $$specs{'Status'} = 'uncalculated';
    } # end if

	my $makeReady = openprint::service::get_price( $log, $dbh, $variable, $$specs{'ServiceType'}.'MakeReady', undef, undef );
	my $minCharge = openprint::service::get_price( $log, $dbh, $variable, $$specs{'ServiceType'}.'Minimum', undef, undef );

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{'txtPressSheetComboItems'} ? $$specs{'txtQuantity'.$qty_index} * $$specs{'txtPressSheetComboItems'} : $$specs{'txtQuantity'.$qty_index};
		$qty = $$specs{'txtItemsPerPackage'} ? ceil( $qty/$$specs{'txtItemsPerPackage'}) : 0;

		$$specs{'hdnBreakdown'.$qty_index} .= "Minimum Charge: $minCharge\n";
		$$specs{'hdnBreakdown'.$qty_index} .= "Makeready: $makeReady\n";
		my $price = 0;
		my $unitPrice = 0;
		if ( $qty ) {
			$unitPrice = openprint::service::get_price( $log, $dbh, $variable, $$specs{'ServiceType'}, $qty, undef );
			$price = $unitPrice * $qty + $makeReady;
			$$specs{'hdnBreakdown'.$qty_index} .= "Pricing for quantity $qty_index: $qty $$specs{'ServiceType'} * $unitPrice = $price\n";
			if ( $$specs{'rdbCardboardBacking'} eq 'Y' ) {
				my $printing_specs = openprint::service::get_specs_ref( $project_index, $services{''}[0] );

				if ( my @Materials = openprint::Material::find('name'=>'CardboardBacking') ) {
					my %CardboardPrice = $Materials[0]->get_price( $qty, undef );
					if ( $CardboardPrice{'units'} eq 'Per Square Inch' ) {
						$CardboardPrice{'Total'} = $CardboardPrice{'Price'} * $$printing_specs{'txtFinalWidth'} * $$printing_specs{'txtFinalHeight'};
					} elsif ( $CardboardPrice{'units'} eq 'Per Square Foot' ) {
						$CardboardPrice{'Total'} = $CardboardPrice{'Price'} * ($$printing_specs{'txtFinalWidth'} * $$printing_specs{'txtFinalHeight'}/144);
					} elsif ( $CardboardPrice{'units'} eq 'Per Pad' ) {
						$CardboardPrice{'Total'} = $CardboardPrice{'Price'};
					} # end if
					$$specs{'hdnBreakdown'.$qty_index} .= "\tCardboard Price: $CardboardPrice{'Price'} $CardboardPrice{'units'} * $$printing_specs{'txtFinalWidth'} x $$printing_specs{'txtFinalHeight'} = $CardboardPrice{'Total'} per package\n";
					$price += $CardboardPrice{'Total'} * $qty;
				} # end if
			} # end if
			$price = $minCharge if $price < $minCharge;

		} # end if
		$$specs{'txtPackageQuantity'.$qty_index} = $qty;
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $unitPrice );
	} # end foreach

	return $status;
} # end sub calc

sub summary {
    my ( $Project, $service_id, $specs, $qty_index ) = @_;
    $specs = openprint::service::get_specs_ref( $Project->id(), $service_id ) if ! $specs;
    my $text = '';
    if ( $qty_index ) {
        $text .= $$specs{'txtPackageQuantity'.$qty_index};
        if ( $$specs{'ServiceType'} =~ /Wrap/i ) {
            $text .= ' wrap' . ($$specs{'txtPackageQuantity'.$qty_index} > 1 ? 's' : '');
        } elsif ( $$specs{'ServiceType'} =~ /Bundling/i ) {
            $text .= ' bundle' . ($$specs{'txtPackageQuantity'.$qty_index} > 1 ? 's' : '');
        } # end if
    } else {
        $text .= $$specs{'txtItemsPerPackage'} . ' items';
        if ( $$specs{'ServiceType'} =~ /Wrap/i ) {
            $text .= ' per wrap';
        } elsif ( $$specs{'ServiceType'} =~ /Bundling/i ) {
            $text .= ' per bundle';
        } # end if
        $text .= $$specs{'rdbCardboardBacking'} eq 'Y' ? ' with cardboard backing.' : '';
    } # end if
    return $text;
} # end sub summary


1;
__END__
