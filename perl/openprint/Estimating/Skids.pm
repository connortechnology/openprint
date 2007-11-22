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
use POSIX qw(ceil);

require openprint::project;
require openprint::service;

require sql;

my $debug = 0;

my %variables = (
	'txtFinalWidth'=>['output'],'txtFinalHeight'=>['output'],
	'txtPackageQuantity1' => ['save','output'],
	'txtPackageQuantity2' => ['save','output'],
	'txtPackageQuantity3' => ['save','output'],
	'txtUnitPrice1' => ['output'], 'txtUnitPrice2' => ['output'], 'txtUnitPrice3' => ['output'],
	'txtPrice1' => ['save','output'], 'txtPrice2' => ['save','output'], 'txtPrice3' => ['save','output'],
	'txtFinishedCalliper' => ['save','output'],
	'txtFinishedWeight' => ['save','output'],
	'txtPackageWidth' => ['save','output'],'txtPackageHeight' => ['save','output'],'txtPackageDepth' => ['save','output'],
	'ddmPackageType' => ['save','output'], 'chkOverridePackageType'=>['save'],
	'txtItemsPerPackage' => ['save','output'], 'chkOverrideItemsPerPackage'=>['save'],
	'txtPackageWeight' => ['save','output'],
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

	my $maxWeight = 1500;
	$maxWeight = 40 if $$specs{'ServiceType'} eq 'PlainCartons';

	my $makeReady = openprint::service::get_price( $log, $dbh, $variable, $$specs{'ServiceType'}.'MakeReady', undef, undef );
	my $serviceCharge = openprint::service::get_price( $log, $dbh, $variable, $$specs{'ServiceType'}, undef, undef );
	my $packingCharge = openprint::service::get_price( $log, $dbh, $variable, $$specs{'ServiceType'}.'Packing', undef, undef );

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();
	my $printing_specs = openprint::service::get_specs_ref( $project_index, $services{''}[0] );
	@$specs{'txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	if ( ! ( $$specs{'txtFinalWidth'} and $$specs{'txtFinalHeight'} ) ) {
		@$specs{'txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtWidth','txtHeight'};
	} # end if
	if ( ! ( $$specs{'txtFinalWidth'} and $$specs{'txtFinalHeight'} ) ) {
		$$specs{'alert'} .= "Dimensions of project are not known. Please enter them.";
		return 'uncalculated';
	} # end if
	$$specs{'txtFinishedCalliper'} = openprint::print::get_finished_calliper( $project_index );
	if ( ! $$specs{'txtFinishedCalliper'} ) {
		return 'uncalculated';
	} # end if
	$$specs{'txtFinishedWeight'} = 1 * openprint::print::get_finished_weight( $project_index, 1 );
	if ( ! $$specs{'txtFinishedWeight'} ) {
		return 'uncalculated';
	} # end if
	
    foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
        if ( ! $$specs{"txtQuantity$qty_index"} > 0 ) {
            next;
        } # end if
		$$specs{'hdnBreakdown'.$qty_index} = '';
        my $qty = $$specs{"txtQuantity$qty_index"};

		my $material_weight = 0;
		my $material_charge;
		my $skidItemQty = 0;
		if ( $$specs{'ServiceType'} eq 'PlainCartons' ) {
			my $best_price = 0;
			my %material_ids;
			if ( $$specs{'chkOverridePackageType'} eq 'Y' ) {
				%material_ids = map { $_->name(), $_->id() } openprint::Material::find('name'=>$$specs{'ddmPackageType'} );
			} else {
				%material_ids = map { $_->name(), $_->id() } openprint::Material::find('name_like'=>'Plain Carton%' );
			} # end if
			foreach my $id ( keys %material_ids ) {
				my ( $items_per_package, $width, $height, $depth );
				if ( $id eq 'Plain Carton' ) {
					if ( $$specs{'chkOverrideItemsPerPackage'} ne 'Y'  ) {
						# Make sure it's not too heavy
						$items_per_package = int ( $maxWeight / $$specs{'txtFinishedWeight'} );
					} else {
						$items_per_package = int $$specs{'txtItemsPerPackage'};
					} # end if

				} elsif ( $id =~ /Plain Carton (\d*)x(\d*)x(\d*)/ ) {
					( $width, $height, $depth ) = ( $1, $2, $3 );
					if ( $width*$height*$depth==972 ) {
						$maxWeight = 30;
					} # end if
					my $setup1 = new openprint::Imposition();
					my $setup2 = new openprint::Imposition();

					openprint::imposition::calc_setup( $setup1, @$specs{'txtFinalWidth','txtFinalHeight'}, $width, $height );
					openprint::imposition::calc_setup( $setup2, @$specs{'txtFinalHeight','txtFinalWidth'}, $width, $height );
					my $imposition = $setup1->imposition() > $setup2->imposition() ? $setup1->imposition() : $setup2->imposition();
					next if ! $imposition;

					if ( $$specs{'chkOverrideItemsPerPackage'} ne 'Y'  ) {
						$items_per_package = int ( $depth/$$specs{'txtFinishedCalliper'} * $imposition );
						# Make sure it's not too heavy
						if ( $items_per_package > int ( $maxWeight / $$specs{'txtFinishedWeight'} ) ) {
							$items_per_package = int ( $maxWeight / $$specs{'txtFinishedWeight'} );
						} # end if
					} else {
						$items_per_package = int $$specs{'txtItemsPerPackage'};
					} # end if
				} # end if

				next if ! $items_per_package;
				
				my $price;
				if ( my @Materials = openprint::Material::find('name'=>$id) ) {
					my %MaterialPrice = $Materials[0]->get_price( undef, undef );
					$price = $MaterialPrice{Price};
				} # end if
				my $compare_price = ceil($qty/$items_per_package) * ( $price + $serviceCharge + $packingCharge );
				if ( $best_price == 0 or $compare_price < $best_price ) {
					$material_charge = $price;
					$best_price = $compare_price;
					@$specs{'ddmPackageType','txtItemsPerPackage'} = ( $id, $items_per_package );
					@$specs{'txtPackageWidth','txtPackageHeight','txtPackageDepth'} = ( $width, $height, $depth );
				} # end if
			} # end foreach Material
		} else {
			if ( $$specs{'chkOverrideItemsPerPackage'} ne 'Y'  ) {
# Make sure it's not too heavy
				$$specs{'txtItemsPerPackage'} = int ( $maxWeight / $$specs{'txtFinishedWeight'} );
			} else {
				$$specs{'txtItemsPerPackage'} = int $$specs{'txtItemsPerPackage'};
			} # end if
			if ( my @Materials = openprint::Material::find('name'=>$$specs{'ServiceType'}) ) {
				my %MaterialPrice = $Materials[0]->get_price( undef, undef );
				$material_charge = $MaterialPrice{Price};
			} # end if
		} # end if
		$$specs{'txtPackageWeight'} = $$specs{'txtFinishedWeight'} * $$specs{'txtItemsPerPackage'};

		if ( $$specs{'txtItemsPerPackage'} ) {
			$$specs{"totalWeight$qty_index"} = sprintf('%.2f', (int( $qty/$$specs{'txtItemsPerPackage'} ) * $$specs{'txtPackageWeight'}) + (($qty % $$specs{'txtItemsPerPackage'} ) * $$specs{'txtFinishedWeight'}) );
		} # end if
		$qty = ceil( $$specs{'txtItemsPerPackage'} ? $qty/$$specs{'txtItemsPerPackage'} : 0 );

		$$specs{'hdnBreakdown'.$qty_index} .= "Qty $qty_index : Package Qty: $qty, MakeReady: $makeReady, Packing Charge: $packingCharge: Service Charge: $serviceCharge, Material Charge: $material_charge<br/>";

		my $unitPrice = $material_charge + $serviceCharge + $packingCharge;
		my $price = $makeReady + $qty * $unitPrice;

		$$specs{"txtPackageQuantity$qty_index"} = $qty;
		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.4f', $unitPrice );

		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
		$$specs{'txtPackageWeight'} = sprintf('%.2f', $$specs{'txtPackageWeight'} );
	} # end foreach qty
	$$specs{'txtFinishedWeight'} = sprintf( '%.4f', $$specs{'txtFinishedWeight'} );

	return $status;
} # end sub calc_skids

sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	if ( $$variable{'ServiceType'} eq 'PlainCartons' ) {
		$$variable{'PackageTypes'} = ssi::make_drop_down( [ map { $_->name(), $_->name() } openprint::Material::find('name_like'=>'Plain Carton%' ) ] );
	} # end if
}

sub summary {
	my ( $project_id, $service_id, $specs, $qty_index ) = @_;
	$specs = openprint::service::get_specs_ref( $project_id, $service_id ) if ! $specs;


	if ( $qty_index ) {
		my $summary;
		my $Project = new openprint::Project( $project_id );
		my %services = $Project->get_services();
		if ( $services{'BulkSkids'} ) {
			if ( $services{'BulkSkids'}[0] == $service_id ) {
				$summary .= $$specs{"txtPackageQuantity$qty_index"} . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? ' skid' : ' skids' );
				my $g = Math::Units::convert( $$specs{'totalWeight'.$qty_index}, 'lbs','g');
				if ( $g > 1000 ) {
					$summary .= sprintf( ', Total Weight: %.0flbs (%.0fkg)', $$specs{'totalWeight'.$qty_index}, $g/1000 );
				} else {
					$summary .= sprintf( ', Total Weight: %.0flbs (%.0fg)', $$specs{'totalWeight'.$qty_index}, $g );
				} # end if
			} else {
				$summary .= $$specs{"txtPackageQuantity$qty_index"} . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? ' cartons' : ' cartons' );
			} # end if
		} else {
			$summary .= $$specs{"txtPackageQuantity$qty_index"} . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? ' cartons' : ' cartons' );
			my $g = Math::Units::convert( $$specs{'totalWeight'.$qty_index}, 'lbs','g');
			if ( $g > 1000 ) {
				$summary .= sprintf( ', Total Weight: %.0flbs (%.0fkg)', $$specs{'totalWeight'.$qty_index}, $g/1000 );
			} else {
				$summary .= sprintf( ', Total Weight: %.0flbs (%.0fg)', $$specs{'totalWeight'.$qty_index}, $g );
			} # end if
		} # end if
		return $summary;
	} else {
		my $g = Math::Units::convert( $$specs{'txtPackageWeight'}, 'lbs','g');
		if ( $g > 1000 ) {
		return sprintf( 'Weight: %.1flbs (%.0fkg)', $$specs{'txtPackageWeight'}, $g/1000 );
		} else {
		return sprintf( 'Weight: %.1flbs (%.0fg)', $$specs{'txtPackageWeight'},  $g );
		} # end if
	} # end if
} # end sub summary

1;
__END__
