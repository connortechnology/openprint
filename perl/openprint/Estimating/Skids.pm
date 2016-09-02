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

use strict;
package openprint::Estimating::Skids;
use POSIX qw(ceil);

require openprint::service;

use constant DEBUG=>0;

my %variables = (
	'txtFinalWidth'=>['output'],'txtFinalHeight'=>['output'],
	'txtPackageQuantity1' => ['save','output'], 'txtPackageQuantity2' => ['save','output'], 'txtPackageQuantity3' => ['save','output'],
	'txtUnitPrice1' => ['output'], 'txtUnitPrice2' => ['output'], 'txtUnitPrice3' => ['output'],
	'MPrice1' => ['save','output'], 'MPrice2' => ['save','output'], 'MPrice3' => ['save','output'],
	'txtPrice1' => ['save','output'], 'txtPrice2' => ['save','output'], 'txtPrice3' => ['save','output'],
	'Markup1'=>['save'], 'Markup2'=>['save'], 'Markup3'=>['save'],
	'OverridePrice1'=>['save'], 'OverridePrice2'=>['save'], 'OverridePrice3'=>['save'],
	'txtFinishedCalliper' => ['save','output'], 'chkOverrideFinishedCalliper' => ['save'],
	'txtFinishedWeight' => ['save','output'],
	'ddmPackageType1' => ['save','output'], 'OverridePackageType1'=>['save'],
	'ddmPackageType2' => ['save','output'], 'OverridePackageType2'=>['save'],
	'ddmPackageType3' => ['save','output'], 'OverridePackageType3'=>['save'],
	'items_per_package' => ['save'], 'txtItemsPerPackage1' => ['save','output'], 'txtItemsPerPackage2' => ['save','output'], 'txtItemsPerPackage3' => ['save','output'], 
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

sub has_overrides {
    my ( $Project, $service_id, $specs, $qty_index ) = @_;
    $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

    my @v;
    if ( $qty_index ) {
            push @v, map { $$specs{$_.$qty_index} ? $_ : () } (
					'OverridePrice','OverridePackageType','OverrideItemsPerPackage',
                    );
    } # end if

    return @v;

} # end sub has_overrides

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
	my ( $Project, $type ) = @_;
# type is actually category name, not material type

	if ( $type eq 'BulkSkids' ) {
		my $finished_weight = $Project->finished_weight();
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			if ( $finished_weight * $$Project{'quantity'.$qty_index} > 1500 ) {
				return 1;
			} # end if
		} # end freach qty_index
	} elsif ( $type eq 'PlainCartons' ) {
		
	} # end if
	return 0;
} # end sub neccessary 

# This doesn't use service_index for a reason.  THe idea is that we can call this on some specs and see what would happen, without ever actually adding the service.
sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	$log->debug( " ********************** START OF CALC SKIDS type:($$specs{ServiceType})**********************");
	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	my $ServiceType = $Project->ServiceType( $service_index );

	my $makeReady = openprint::service::get_price( $ServiceType->name().'MakeReady', undef, undef );
	my $serviceCharge = openprint::service::get_price( $ServiceType->name(), undef, undef );
	my $packingCharge = openprint::service::get_price( $ServiceType->name().'Packing', undef, undef );

	my $printing_specs;
	if ( $Project->signatures() == 1 ) {
		$printing_specs = openprint::service::get_specs_ref( $Project, $$services{Signature}[0] );
	} else {
		$printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );
	} # end if
	@$specs{'txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtFinalWidth','txtFinalHeight'};
	if ( ! ( $$specs{txtFinalWidth} and $$specs{txtFinalHeight} ) ) {
		@$specs{'txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtWidth','txtHeight'};
	} # end if
	if ( ! ( $$specs{txtFinalWidth} and $$specs{txtFinalHeight} ) ) {
		$$specs{alert} .= "Dimensions of project are not known. Please enter them.";
		return $$specs{Status} = 'uncalculated';
	} # end if
	if ( $$specs{chkOverrideFinishedCalliper} ne 'Y' ) {
		$$specs{txtFinishedCalliper} = $Project->calliper();
	} # end if
	if ( ! ( 1*$$specs{txtFinishedCalliper} ) ) {
		$$specs{alert} .= 'Unable to calculate the calliper of the project.  Please recalculate printing services.';
		return $$specs{Status} = 'uncalculated';
	} # end if
	$$specs{txtFinishedWeight} = $Project->finished_weight( 1 );
	if ( ! $$specs{txtFinishedWeight} ) {
		$$specs{alert} .= 'Unable to calculate the weight of the project.  Please recalculate printing services.';
		return $$specs{Status} = 'uncalculated';
	} # end if
	
    foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"Markup$qty_index"} =~ s/[^\d\.\-]//g;
		$$specs{"txtPrice$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} =~ s/[^\d\.]//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
        if ( ! $$specs{"txtQuantity$qty_index"} > 0 ) {
			$log->error("EMpty txtQuantity for QTY $qty_index");
			$$specs{alert} .= "Please enter the # of items to pack for quantity $qty_index.<br/>";
            next;
        } # end if
		$$specs{'hdnBreakdown'.$qty_index} = '';
        my $qty = $$specs{"txtQuantity$qty_index"};
		$qty *= $$printing_specs{Versions} if $$printing_specs{Versions};
		$$specs{'hdnBreakdown'.$qty_index} .= "Packaging $qty items<br/>";

		my $material_charge = 0;
		my $best_price = 0;
		my @Materials;
		if ( $$specs{'OverridePackageType'.$qty_index} eq 'Y' ) {
			my $Material = new openprint::Material( $$specs{'ddmPackageType'.$qty_index} );
			@Materials = ( $Material );
		} else {
			@Materials = openprint::Material->find('category'=>$ServiceType->name() );
			$$specs{'ddmPackageType'.$qty_index} = '';
		} # end if
$log->debug("Materials: " . map { $_->name() } @Materials ) if DEBUG;
		if ( ! @Materials ) {
			$$specs{'hdnBreakdown'.$qty_index} .= "There are no materials for " . $ServiceType->name();
		} # end if
		if ( $$specs{'OverrideItemsPerPackage'.$qty_index} ne 'Y'  ) {
			$$specs{'txtItemsPerPackage'.$qty_index} = '';
		} # end if

		foreach my $Material ( @Materials ) {
			my ( $items_by_weight, $items_by_size, $items_per_package );

			$$specs{'hdnBreakdown'.$qty_index} .= '<fieldset><legend>'.$Material->name().'</legend>';

			if ( $$specs{'OverrideItemsPerPackage'.$qty_index} ne 'Y'  ) {
# Make sure it's not too heavy
				$items_by_weight = int ( $Material->specification('Maximum Weight') / $$specs{txtFinishedWeight} );
				$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Items by weight: %d<br/>', $items_by_weight );

				my $width = $Material->specification('Width');
				my $height = $Material->specification('Height');
				my $depth = $Material->specification('Depth');
#if ( $width*$height*$depth==972 ) {
#$maxWeight = 30;
#} # end if
				if ( $width and $height and $depth ) {
					my $setup = openprint::imposition::fit( @$specs{'txtFinalWidth','txtFinalHeight'}, $width, $height );

					my $imposition = $$setup{imposition};
					if ( $imposition ) {
						# Fits flat
						$items_by_size = int ( ($depth/$$specs{txtFinishedCalliper}) * $imposition );
						$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Items by size: %s/%s * %dout = %d<br/>', $depth, $$specs{txtFinishedCalliper}, $imposition, $items_by_size );
					} else {
						# Try Rolling
						my ( $item_width, $item_length ) = sort @$specs{'txtFinalWidth','txtFinalHeight'};
						if ( $width == $height and $depth >= $item_width ) {
							$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Rolling %sx%s on %s<br/>', $item_width, $item_length, $depth );
							# L = pi * N * (D+d)/2 where N=(D-d)/(2*t)
							my $l = 3.14 * ( ( $width-1 ) / ( 2 * $$specs{txtFinishedCalliper} ) ) * ( $width + 1 )/2;
							$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Max Length: %d<br/>', $l );
							$items_by_size = int($l/$item_length);
						} elsif ( $width == $height and $depth >= $item_length ) {
							$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Rolling %sx%s on %s<br/>', $item_width, $item_length, $depth );
							# L = pi * N * (D+d)/2 where N=(D-d)/(2*t)
							my $l = 3.14 * ( ( $height-1 ) / ( 2 * $$specs{txtFinishedCalliper} ) ) * ( $height + 1 )/2;
							$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Max Length: %d<br/>', $l );
							$items_by_size = int($l/$item_width);
						} else {
							$$specs{'hdnBreakdown'.$qty_index} .= "Doesn't fit and item can't be rolled<br/>";
						} # end if
					} # end if

# Make sure it's not too heavy
					if ( $items_by_size > $items_by_weight ) {
						$items_per_package = $items_by_weight;
					} else {
						$items_per_package = $items_by_size;
					} # end if
				} else {
					$items_per_package = $items_by_weight;
				} # end if
				if ( $$services{Signature} and @{$$services{Signature}} ) {
					my $sig_specs = openprint::service::get_specs_ref( $Project, $$services{Signature}[0] );
					if ( $$sig_specs{Versions} ) {
						my $versions_per_package = int( $qty / $$sig_specs{Versions} );
						$openprint::log->debug("Per package due to versions: $qty / $$sig_specs{Versions} = $versions_per_package");
						if ( $versions_per_package < $items_per_package ) {
							$items_per_package = $versions_per_package;
						} # end if
					} else {
# No versions?
						#$openprint::log->debug("No versions");
					} # end if
				} else {
					$openprint::log->debug("No signatnures");
				} # end if

				if ( $$specs{items_per_package} ) {
					if ( $$specs{items_per_package} > $items_per_package ) {
						$$specs{alert} .= "Can't fit that many.<br/>";
						next;
					} 
					$items_per_package = $$specs{items_per_package};
				} # end if

			} else {
				$items_per_package = int $$specs{'txtItemsPerPackage'.$qty_index};
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Items per: %d<br/>', $items_per_package );
			if ( ! $items_per_package ) {
				$$specs{'hdnBreakdown'.$qty_index} .= '</fieldset>';
				next;
			} # end if

			my $package_qty = ceil($qty/$items_per_package);

			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('# of packages: %d<br/>', $package_qty );
			
			my $price;
			my %MaterialPrice = $Material->get_price( $package_qty, undef );
			$price = $MaterialPrice{Price};
			my $compare_price = $package_qty * ( $price + $serviceCharge + $packingCharge );
			if ( $best_price == 0 or $compare_price < $best_price ) {
				$material_charge = $price;
				$best_price = $compare_price;
				@$specs{'ddmPackageType'.$qty_index,'txtItemsPerPackage'.$qty_index} = ( $Material->id(), $items_per_package );
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReady: %.2f, Packing Charge: %.2f: Service Charge: %.2f, Material Charge: %.2f<br/></fieldset>', $makeReady, $packingCharge, $serviceCharge, $material_charge );
		} # end foreach Material

		my $m_qty = 0;
		if ( $$specs{'txtItemsPerPackage'.$qty_index} > 0 ) {
			$$specs{'txtPackageWeight'.$qty_index} = Math::Round::nearest( 0.01, $$specs{txtFinishedWeight} * $$specs{'txtItemsPerPackage'.$qty_index} );
			$$specs{"totalWeight$qty_index"} = sprintf('%.2f', (int( $qty/$$specs{'txtItemsPerPackage'.$qty_index} ) * $$specs{"txtPackageWeight$qty_index"}) + (($qty % $$specs{'txtItemsPerPackage'.$qty_index} ) * $$specs{txtFinishedWeight}) );
			$qty = ceil( $qty/$$specs{'txtItemsPerPackage'.$qty_index} );
			$m_qty = ceil( 1000/$$specs{'txtItemsPerPackage'.$qty_index} );
		} else {
			$qty = 0;
		} # end if

		if ( ! $qty ) {
			$status = 'uncalculated';
		} # end if

		my $unitPrice = $material_charge + $serviceCharge + $packingCharge;
		my $price = $makeReady + $qty * $unitPrice;

		$$specs{"txtPackageQuantity$qty_index"} = $qty;
		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{UnitPriceFormat}, $unitPrice * (1+$Project->markup()/100) );
		$$specs{"MPrice$qty_index"} = sprintf( $openprint::config{UnitPriceFormat}, $unitPrice * $m_qty * (1+$Project->markup()/100) );

		if ( $$specs{'OverridePrice'.$qty_index} ne 'Y' ) {
			
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, ( $$specs{"Markup$qty_index"} ? $price*(1+$$specs{"Markup$qty_index"}/100) : $price ) * (1+$Project->markup()/100) );
		} else {
			$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{ProjectMoneyFormat}, $$specs{"txtPrice$qty_index"} );
		} # end if
	} # end foreach qty
	$$specs{txtFinishedWeight} = sprintf( '%.4f', $$specs{txtFinishedWeight} );
$log->debug("Status: $status");
	return $$specs{Status} = $status;
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
		my $Material = new openprint::Material( $$specs{'ddmPackageType'.$qty_index} );

		if ( $$services{BulkSkids} ) {
			if ( $$services{BulkSkids}[0] == $service_id ) {
				$summary .= $$specs{"txtPackageQuantity$qty_index"} . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? ' skid' : ' skids' );
				my $g = $$specs{'totalWeight'.$qty_index} * 453.5923696;
				if ( $g > 1000 ) {
					$summary .= sprintf( ', Total Weight: %slbs (%skg)', 
							Number::Format::format_number( Math::Round::nearest( 1, $$specs{'totalWeight'.$qty_index}) ), 
							Number::Format::format_number( Math::Round::nearest( 1, $g/1000 ) ),
							);
				} else {
					$summary .= sprintf( ', Total Weight: %slbs (%sg)', 
							Number::Format::format_number( Math::Round::nearest( 1, $$specs{'totalWeight'.$qty_index}) ), 
							Number::Format::format_number( Math::Round::nearest( 1, $g ) ),
					);
				} # end if
			} else {
				if ( $$Material{name} ) {
					$summary .= $$specs{"txtPackageQuantity$qty_index"} . ' ' . $Material->name() . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? '' : 's' );
				} # end if
			} # end if
		} else {
			if ( $$specs{ServiceType} eq 'Gaylords' ) {
				$summary .= $$specs{"txtPackageQuantity$qty_index"} . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? ' gaylord' : ' gaylords' );
				my $g = $$specs{'totalWeight'.$qty_index} * 453.5923696;
				if ( $g > 1000 ) {
					$summary .= sprintf( ', Total Weight: %slbs (%skg)', 
							Number::Format::format_number( Math::Round::nearest( 1, $$specs{'totalWeight'.$qty_index}) ), 
							Number::Format::format_number( Math::Round::nearest( 1, $g/1000 ) ),
							);
				} else {
					$summary .= sprintf( ', Total Weight: %slbs (%sg)', 
							Number::Format::format_number( Math::Round::nearest( 1, $$specs{'totalWeight'.$qty_index}) ), 
							Number::Format::format_number( Math::Round::nearest( 1, $g ) ),
					);
				} # end if
			} else {
				$summary .= $$specs{"txtPackageQuantity$qty_index"} . ' ' . $Material->name() . ( $$specs{"txtPackageQuantity$qty_index"} == 1 ? '' : 's' );
				my $g = $$specs{'totalWeight'.$qty_index} * 453.5923696;
				if ( $g > 1000 ) {
					$summary .= sprintf( ', Total Weight: %slbs (%skg)', 
							Number::Format::format_number( Math::Round::nearest( 1, $$specs{'totalWeight'.$qty_index}) ), 
							Number::Format::format_number( Math::Round::nearest( 1, $g/1000 ) ),
					);
				} else {
					$summary .= sprintf( ', Total Weight: %slbs (%sg)', 
							Number::Format::format_number( Math::Round::nearest( 1, $$specs{'totalWeight'.$qty_index}) ), 
							Number::Format::format_number( Math::Round::nearest( 1, $g ) ),
					);
				} # end if
			} # end if
		} # end if
		return $summary;
	} else {
	} # end if
} # end sub summary

sub save {
}

1;
__END__
