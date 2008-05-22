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

package openprint::Estimating::Skids;
use strict;
use warnings;
no warnings qw(uninitialized);
use POSIX qw(ceil);

require openprint::project;
require openprint::service;

require sql;

my $debug = 0;

my %variables = (
	'txtFinalWidth'=>['output'],'txtFinalHeight'=>['output'],
	'txtPackageQuantity1' => ['save','output'], 'txtPackageQuantity2' => ['save','output'], 'txtPackageQuantity3' => ['save','output'],
	'txtUnitPrice1' => ['output'], 'txtUnitPrice2' => ['output'], 'txtUnitPrice3' => ['output'],
	'txtPrice1' => ['save','output'], 'txtPrice2' => ['save','output'], 'txtPrice3' => ['save','output'],
	'Markup1'=>['save'], 'Markup2'=>['save'], 'Markup3'=>['save'],
	'OverridePrice1'=>['save'], 'OverridePrice2'=>['save'], 'OverridePrice3'=>['save'],
	'txtFinishedCalliper' => ['save','output'],
	'txtFinishedWeight' => ['save','output'],
	'ddmPackageType1' => ['save','output'], 'OverridePackageType1'=>['save'],
	'ddmPackageType2' => ['save','output'], 'OverridePackageType2'=>['save'],
	'ddmPackageType3' => ['save','output'], 'OverridePackageType3'=>['save'],
	'txtItemsPerPackage1' => ['save','output'], 'txtItemsPerPackage2' => ['save','output'], 'txtItemsPerPackage3' => ['save','output'], 
	'OverrideItemsPerPackage1'=>['save'], 'OverrideItemsPerPackage2'=>['save'], 'OverrideItemsPerPackage3'=>['save'],
	'txtPackageWeight1' => ['save','output'], 'txtPackageWeight2' => ['save','output'], 'txtPackageWeight3' => ['save','output'],
	'totalWeight1' => ['save','output'],'totalWeight2' => ['save','output'],'totalWeight3' => ['save','output'],
	'alert'=>['output'], 
	'hdnBreakdown1'=>['output'], 'hdnBreakdown2'=>['output'], 'hdnBreakdown3'=>['output'],
);

sub variables {
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k, if sets::isin( 'save', $variables{$k} );
	} # end foreach;
	return @v;
}

sub outputs {
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k, if sets::isin( 'output', $variables{$k} );
	} # end foreach;
	return @v;
}
sub no_outputs {
	my @v;
	foreach my $k ( keys %variables ) {
		push @v, $k, if ! sets::isin( 'output', $variables{$k} );
	} # end foreach;
	return @v;
}

sub neccessary {
	my ( $Project ) = @_;

	my $finished_weight = openprint::print::get_finished_weight( $Project->id() );
	foreach my $qty_index ( 1 .. 3 ) {
		if ( $finished_weight * $$Project{'quantity'.$qty_index} > 1500 ) {
			return 1;
		} # end if
	} # end freach qty_index
	return 0;
} # end sub neccessary 

# This doesn't use service_index for a reason.  THe idea is that we can call this on some specs and see what would happen, without ever actually adding the service.
sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	$log->debug( " ********************** START OF CALC SKIDS type:($$specs{'ServiceType'})**********************");
	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	my $ServiceType = $Project->ServiceType( $service_index );

	my $makeReady = openprint::service::get_price( $ServiceType->name().'MakeReady', undef, undef );
	my $serviceCharge = openprint::service::get_price( $ServiceType->name(), undef, undef );
	my $packingCharge = openprint::service::get_price( $ServiceType->name().'Packing', undef, undef );

	my $printing_specs = openprint::service::get_specs_ref( $project_index, $$services{''}[0] );
	@$specs{'txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	if ( ! ( $$specs{'txtFinalWidth'} and $$specs{'txtFinalHeight'} ) ) {
		@$specs{'txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtWidth','txtHeight'};
	} # end if
	if ( ! ( $$specs{'txtFinalWidth'} and $$specs{'txtFinalHeight'} ) ) {
		$$specs{'alert'} .= "Dimensions of project are not known. Please enter them.";
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	$$specs{'txtFinishedCalliper'} = openprint::print::get_finished_calliper( $project_index );
	if ( ! $$specs{'txtFinishedCalliper'} ) {
		$$specs{'alert'} .= 'Unable to calculate the calliper of the project.  Please recalculate printing services.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	$$specs{'txtFinishedWeight'} = 1 * openprint::print::get_finished_weight( $project_index, 1 );
	if ( ! $$specs{'txtFinishedWeight'} ) {
		$$specs{'alert'} .= 'Unable to calculate the weight of the project.  Please recalculate printing services.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	
    foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
        if ( ! $$specs{"txtQuantity$qty_index"} > 0 ) {
            next;
        } # end if
		$$specs{'hdnBreakdown'.$qty_index} = '';
        my $qty = $$specs{"txtQuantity$qty_index"};

		my $material_charge = 0;
		my $best_price = 0;
		my @Materials;
		if ( $$specs{'OverridePackageType'.$qty_index} eq 'Y' ) {
			my $Material = new openprint::Material( $$specs{'ddmPackageType'.$qty_index} );
			@Materials = ( $Material );
		} else {
			@Materials = openprint::Material::find('category'=>$ServiceType->name() );
		} # end if

		foreach my $Material ( @Materials ) {
			my ( $items_by_weight, $items_by_size, $items_per_package );

			$$specs{'hdnBreakdown'.$qty_index} .= '<fieldset><legend>'.$Material->name().'</legend>';

			if ( $$specs{'OverrideItemsPerPackage'.$qty_index} ne 'Y'  ) {
# Make sure it's not too heavy
				$items_by_weight = int ( $Material->specification('Maximum Weight') / $$specs{'txtFinishedWeight'} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Items by weight: %d<br/>', $items_by_weight );

				my $width = $Material->specification('Width');
				my $height = $Material->specification('Height');
				my $depth = $Material->specification('Depth');
#if ( $width*$height*$depth==972 ) {
#$maxWeight = 30;
#} # end if
				if ( $width and $height and $depth ) {
					my $setup1 = new openprint::Imposition();
					my $setup2 = new openprint::Imposition();

					openprint::imposition::calc_setup( $setup1, @$specs{'txtFinalWidth','txtFinalHeight'}, $width, $height );
					openprint::imposition::calc_setup( $setup2, @$specs{'txtFinalHeight','txtFinalWidth'}, $width, $height );
					my $imposition = $setup1->imposition() > $setup2->imposition() ? $setup1->imposition() : $setup2->imposition();
					next if ! $imposition;

					$items_by_size = int ( $depth/$$specs{'txtFinishedCalliper'} * $imposition );
					$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Items by size: %d<br/>', $items_by_size );
# Make sure it's not too heavy
					if ( $items_by_size > $items_by_weight ) {
						$items_per_package = $items_by_weight;
					} else {
						$items_per_package = $items_by_size;
					} # end if
				} else {
					$items_per_package = $items_by_weight;
				} # end if
			} else {
				$items_per_package = int $$specs{'txtItemsPerPackage'.$qty_index};
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Items per: %d<br/>', $items_per_package );
			next if ! $items_per_package;

			my $package_qty = ceil($qty/$items_per_package);

			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('# of packages: %d<br/>', $package_qty );
			
			my $price;
			my %MaterialPrice = $Material->get_price( undef, undef );
			$price = $MaterialPrice{Price};
			my $compare_price = $package_qty * ( $price + $serviceCharge + $packingCharge );
			if ( $best_price == 0 or $compare_price < $best_price ) {
				$material_charge = $price;
				$best_price = $compare_price;
				@$specs{'ddmPackageType'.$qty_index,'txtItemsPerPackage'.$qty_index} = ( $Material->id(), $items_per_package );
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReady: %.2f, Packing Charge: %.2f: Service Charge: %.2f, Material Charge: %.2f<br/>', $makeReady, $packingCharge, $serviceCharge, $material_charge );
		} # end foreach Material

		$$specs{'txtPackageWeight'.$qty_index} = sprintf('%.2f', $$specs{'txtFinishedWeight'} * $$specs{'txtItemsPerPackage'.$qty_index} );

		if ( $$specs{'txtItemsPerPackage'.$qty_index} ) {
			$$specs{"totalWeight$qty_index"} = sprintf('%.2f', (int( $qty/$$specs{'txtItemsPerPackage'.$qty_index} ) * $$specs{"txtPackageWeight$qty_index"}) + (($qty % $$specs{'txtItemsPerPackage'.$qty_index} ) * $$specs{'txtFinishedWeight'}) );
		} # end if
		$qty = ceil( $$specs{'txtItemsPerPackage'.$qty_index} ? $qty/$$specs{'txtItemsPerPackage'.$qty_index} : 0 );

		my $unitPrice = $material_charge + $serviceCharge + $packingCharge;
		my $price = $makeReady + $qty * $unitPrice;

		$$specs{"txtPackageQuantity$qty_index"} = $qty;
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $unitPrice );

		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price*(1+$$specs{"Markup$qty_index"}/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
		} # end if
	} # end foreach qty
	$$specs{'txtFinishedWeight'} = sprintf( '%.4f', $$specs{'txtFinishedWeight'} );

	return $$specs{'Status'} = $status;
} # end sub calc

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

}

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	$specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

	if ( $qty_index ) {
		my $summary;
		my $services = $Project->services();
		my $Material = new openprint::Material( $$specs{'ddmPackageType'} );

		if ( $$services{'BulkSkids'} ) {
			if ( $$services{'BulkSkids'}[0] == $service_id ) {
				$summary .= $$specs{"txtPackageQuantity$qty_index"} . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? ' skid' : ' skids' );
				my $g = Math::Units::convert( $$specs{'totalWeight'.$qty_index}, 'lbs','g');
				if ( $g > 1000 ) {
					$summary .= sprintf( ', Total Weight: %.0flbs (%.0fkg)', $$specs{'totalWeight'.$qty_index}, $g/1000 );
				} else {
					$summary .= sprintf( ', Total Weight: %.0flbs (%.0fg)', $$specs{'totalWeight'.$qty_index}, $g );
				} # end if
			} else {
				if ( $$specs{'ServiceType'} eq 'Gaylords' ) {
					$summary .= $$specs{"txtPackageQuantity$qty_index"} . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? ' gaylord' : ' gaylords' );
				} else {
					$summary .= $$specs{"txtPackageQuantity$qty_index"} . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? ' carton' : ' cartons' );
				} # end if
			} # end if
		} else {
			if ( $$specs{'ServiceType'} eq 'Gaylords' ) {
				$summary .= $$specs{"txtPackageQuantity$qty_index"} . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? ' gaylord' : ' gaylords' );
				my $g = Math::Units::convert( $$specs{'totalWeight'.$qty_index}, 'lbs','g');
				if ( $g > 1000 ) {
					$summary .= sprintf( ', Total Weight: %.0flbs (%.0fkg)', $$specs{'totalWeight'.$qty_index}, $g/1000 );
				} else {
					$summary .= sprintf( ', Total Weight: %.0flbs (%.0fg)', $$specs{'totalWeight'.$qty_index}, $g );
				} # end if
			} else {
				$summary .= $$specs{"txtPackageQuantity$qty_index"} . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? ' carton' : ' cartons' );
				my $g = Math::Units::convert( $$specs{'totalWeight'.$qty_index}, 'lbs','g');
				if ( $g > 1000 ) {
					$summary .= sprintf( ', Total Weight: %.0flbs (%.0fkg)', $$specs{'totalWeight'.$qty_index}, $g/1000 );
				} else {
					$summary .= sprintf( ', Total Weight: %.0flbs (%.0fg)', $$specs{'totalWeight'.$qty_index}, $g );
				} # end if
			} # end if
		} # end if
		return $summary;
	} else {
	} # end if
} # end sub summary

1;
__END__
