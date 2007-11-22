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

package openprint::Estimating::Spiral;
use strict;

require sql;
require openprint::service;
require openprint::Material;

my @variables = (
	'txtPrice1', 'txtPrice2', 'txtPrice3',
	'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
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
} # end sub variables

sub neccessary {
	my ( $Project ) = @_;

	$Project = new openprint::Project( $Project ) if ref $Project ne 'openprint::Project';
	my %services = $Project->get_services();

	return 1 if ! $services{'PlasticCoil'};
	return 1 if ! $services{'MetalCoil'};

	return 0;
} # end sub neccessary

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

$log->debug("SPIRAL!!!!!!!!!!!!!!!!!!");
	# Currently there is no equipmnet for spiral

	my $makeReadyPrice = openprint::service::get_price( $log, $dbh, $variable, 'SpiralPunchingMakeReady', undef, undef );
	my $minimumCharge = openprint::service::get_price( $log, $dbh, $variable, 'SpiralPunchingMinimumCharge', undef, undef );

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();
	my $printing_specs = openprint::service::get_specs_ref( $project_index, $services{''}[0] );

	if ( $$specs{'chkOverrideFinalHeight'} ne 'Y' ) {
		@$specs{'txtFinalHeight'} = $$printing_specs{'txtFinalHeight'};
	} # end if

	my $ProjectType = $Project->Type();

	if ( $$specs{'chkOverrideFinishedCalliper'} ne 'Y' ) {
		$$specs{'txtFinishedCalliper'} = openprint::print::get_finished_calliper( $project_index, undef, $ProjectType->strid() );
	} else {
		$$specs{'txtFinishedCalliper'} =~ s/[\D\.]//g;
	} # end if

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		my $price = 0;
		my $unitPrice = 0;

		$$specs{'hdnBreakdown'.$qty_index} = '';
		$$specs{'hdnBreakdown'.$qty_index} .= "MakeReady: " . sprintf( '%.2f', $makeReadyPrice ) . "\n";
		$$specs{'hdnBreakdown'.$qty_index} .= "MinimumCharge: " . sprintf( '%.2f', $minimumCharge ) . "\n";
		$$specs{"txtQuantity$qty_index"} = int( $$specs{"txtQuantity$qty_index"} );

		if ( $$specs{"txtQuantity$qty_index"} ) {
			my $qty = $$specs{"txtQuantity$qty_index"};
			my %PunchingPrice = openprint::service::get_price_object( $log, $dbh, $variable, 'SpiralPunching', $qty, undef );
			$$specs{'hdnBreakdown'.$qty_index} .= "Punching: " . sprintf( '%.4f', $PunchingPrice{'Price'} ) . "$PunchingPrice{'units'}\n";
			if ( $PunchingPrice{'units'} eq 'Per M' ) {
				$PunchingPrice{'Total'} = ( $PunchingPrice{'Price'} / 1000 ) * $qty;
			} else {
				$PunchingPrice{'Total'} = $PunchingPrice{'Price'} * $qty;
			} # end if

			my %CoilingPrice = openprint::service::get_price_object( $log, $dbh, $variable, 'Coiling', $qty, undef );
			$$specs{'hdnBreakdown'.$qty_index} .= "Coiling: " . sprintf( '%.4f', $CoilingPrice{'Price'} ) . "$CoilingPrice{'units'}\n";
			if ( $CoilingPrice{'units'} eq 'Per M' ) {
				$CoilingPrice{'Total'} = ( $CoilingPrice{'Price'} / 1000 ) * $qty;
			} # end if

			if ( $$specs{'chkOverrideMaterialLength'} ne 'Y' ) {
				$$specs{'txtMaterialLength'} = $$specs{'txtFinalHeight'} * $$specs{"txtQuantity$qty_index"};
			} # end if

			$price = $makeReadyPrice + $PunchingPrice{'Total'} + $CoilingPrice{'Total'};

			if ( my @Materials = openprint::Material::find('name'=>$$specs{'ServiceType'}) ) {
				my %MaterialPrice = $Materials[0]->get_price( $$specs{'txtFinishedCalliper'}, undef );
				if ( $MaterialPrice{'units'} eq 'Project Calliper-Per 36 Inches' ) {
					$MaterialPrice{'Total'} = ( $MaterialPrice{'Price'} /36 ) * $$specs{'txtMaterialLength'};
				} elsif ( $MaterialPrice{'units'} eq 'Project Calliper-Per Inch' ) {
					$MaterialPrice{'Total'} = $MaterialPrice{'Price'} * $$specs{'txtMaterialLength'};
				} else {
					$$specs{'hdnBreakdown'.$qty_index} .= "Unknown units for material";
				} # end if
				$$specs{'hdnBreakdown'.$qty_index} .= "Material: " . sprintf( '%.2f', $MaterialPrice{'Price'} ) . " " . $MaterialPrice{'units'} . "=$MaterialPrice{'Total'}\n";
				$price += $MaterialPrice{'Total'};
			} else {
				$$specs{'hdnBreakdown'.$qty_index} .= 'No material found';
			} # end if
	
			if ( $minimumCharge > 0 and $price < $minimumCharge ) {
				$price = $minimumCharge;
			} # end if
			$unitPrice = $price / $qty;
			$$specs{'hdnBreakdown'.$qty_index} .= "Qty: " . $$specs{"txtQuantity$qty_index"} . ": Price: $price\n";
		} # end if
		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $unitPrice );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
	} # end foreach

	$log->debug("END SPIRAL!!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

1;

__END__
