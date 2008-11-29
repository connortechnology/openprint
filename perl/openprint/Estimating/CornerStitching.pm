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

package openprint::Estimating::CornerStitching;
use strict;

require openprint::project;
require openprint::Equipment;
require openprint::service;

require sql;

# This is an array of all the variables that need to be saved to the database for this service.
my @variables = (
		'txtPageQuantity',
		'ddmEquipment1',
		'ddmEquipment2',
		'ddmEquipment3',
		'txtPrice1',
		'txtPrice2',
		'txtPrice3',
		'txtQuantity1',
		'txtQuantity3',
		'txtQuantity2',
		'ServiceType',
		'txtRunTime1',
		'txtRunTime2',
		'txtRunTime3',
		);

sub variables {
    return @variables;
}

# A function that is smart enough to return true if the project needs folding, and false if it doesn't.
sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();
	if ( $services{NoBindery} ) {
		$log->debug(" ** Project is marked as No bindery, Folding not needed ! ** ");
		return 0;
	} # end if

	if ( $services{''} ) {
		my $printing_specs = openprint::service::get_specs_ref( $project_index, $services{''}[0] );
		if ( $$printing_specs{'rdbTemplateType'} eq 'CornerStitching' ) {
			return 1;
		} # end if
	} # end if

	return 0;
} # end sub neccessary


# Corner Stiching is simple:  Max 96 pages, setup plus per 1000 charge
#

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();

	if ( ! $services{''} ) {
		$$specs{'alert'} = 'No Project service found.<br/>';
		return 'uncalculated';
	} # end if

	# Figure out whether we need a cover
	my $printing_service_index = $services{''}[0];
    my $printing_specs = openprint::service::get_specs_ref( $project_index, $printing_service_index );
	if ( $$printing_specs{'txtTotalPageQuantity'} <= 0 ) {
		$$specs{'alert'} .= 'Unknown # of pages<br/>';
		$status = 'uncalculated';
	} # end if
	@$specs{'txtPageQuantity','txtFinalWidth','txtFinalHeight'} = @$printing_specs{'txtTotalPageQuantity','txtFinalWidth','txtFinalHeight'};

	my @possible_equipment;

	my $error = '';
	my @all_equipment = openprint::Equipment::find( 'Specifications' => {'Stitching Capable'=>'Y'}, 'UseInEstimating'=>'Y','order'=>'strName');

	foreach my $Equipment ( @all_equipment ) {

		my $max_pages = $Equipment->specification('Maximum Pages', undef );
		if ( $max_pages and $printing_specs{'txtTotalPageQuantity'} > $max_pages ) {
			$error .= "For " . $Equipment->name() . ": Only supports $max_pages pages.\n";
		} elsif ( my $reason = $Equipment->fits( @printing_specs{'txtFinalWidth','txtFinalHeight'}, $$specs{'txtCalliper'} ) ) {
			$error .= "For " . $Equipment->name() . ":\n". $reason  . "\n";
		} else {
			push @possible_equipment, $Equipment
		} # end if
	} # end foreach

	if ( ! @possible_equipment ) {
		# alert the user that no equipment is good.
		$$specs{'alert'} = "Our stitching equipment cannot run this project, for the following reasons:\n$error\n Please only print flat sheets and contact another bindery.";
	} # end if

	foreach my $qty_index ( 1 .. 3 ) {
		my %bestPrice;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		next if ! $$specs{"txtQuantity$qty_index"};

		my $bestEquipment;

		my @equipment = ();
		if ( $$specs{"chkOverrideEquipment$qty_index"} eq 'Y' ) {
			@equipment = ( new openprint::Equipment( 'strid'=> $$specs{"ddmEquipment$qty_index"} ) );
		} else {
			@equipment = @possible_equipment;
		} # end if

		foreach my $Equipment ( @equipment ) {

			my %price = {
				'MakeReady' => 0,
				'Service'	=> 0,
				'txtPrice'	=> 0,
				'RunTime'	=> 0,
			};

			$price{'MakeReady'} = openprint::service::get_price( $$specs{'ServiceType'}.'MakeReady', undef, $Equipment );

			$price{'RunTime'} += $Equipment->specification( 'Make Ready', undef );

# Calculate Last Pass
			my $unitsPerHour = $Equipment->specification( 'Units Per Hour', undef );
			my $runtime = $$specs{"txtQuantity$qty_index"}/$unitsPerHour; # in seconds
				$price{'RunTime'} += $runtime * 360;
			my %servicePrice = openprint::service::get_price_object( $$specs{'ServiceType'}, undef, $Equipment );
			if ( $servicePrice{'units'} eq 'Per M' ) {
				$price{'Service'} += $servicePrice{'Price'} * $$specs{'txtQuantity'.$qty_index}/1000;
			} elsif ( $servicePrice{'units'} eq 'Per Hour' ) {
				$price{'Service'} += $servicePrice{'Price'} * $runtime;
			} else {
				$log->debug("Unknown Unit Type: $servicePrice{'units'}");
			} # end if

			$price{'txtPrice'} = $price{'MakeReady'} + $price{'Service'};

			if ( ! $bestPrice{'txtPrice'} or $price{'txtPrice'} < $bestPrice{'txtPrice'} ) {
				$bestEquipment = $Equipment;
				%bestPrice = %price;
			} # end if
			$$specs{'hdnBreakdown'.$qty_index} .= 'Quantity: ' . $$specs{"txtQuantity$qty_index"} .
				", Equipment: " . $Equipment->name() . "\n";
			$$specs{'hdnBreakdown'.$qty_index} .= 'Estimated Run Time: '. sprintf('%.1f', $price{'RunTime'} ) . ",\n";
			$$specs{'hdnBreakdown'.$qty_index} .= 'MakeReady: $' . sprintf( '%.2f', $price{'MakeReady'}).",\n";
			$$specs{'hdnBreakdown'.$qty_index} .= 'Service: $' . sprintf( '%.2f', $price{'Service'}).",\n";
			$$specs{'hdnBreakdown'.$qty_index} .= 'Total: $'. sprintf('%.2f', int($price{'txtPrice'}))."\n";
		} # end foreach
		if ( ! $bestEquipment ) {
			$status = 'uncalculated';
			$$specs{"ddmEquipment$qty_index"} = '';
		} else {
			$$specs{"ddmEquipment$qty_index"} = $bestEquipment->strid();
		} # end if

		$$specs{"txtUnitPrice$qty_index"} = sprintf( $openprint::config{'UnitPriceFormat'}, $bestPrice{'txtPrice'}/$$specs{"txtQuantity$qty_index"} );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $bestPrice{'txtPrice'} );
		$$specs{"txtRunTime$qty_index"} = $bestPrice{'RunTime'};
	} # end foreach
	$log->debug("END CORNER STITCHING!!!!!!!");
	return $status;
} # end sub calc

1;
__END__
