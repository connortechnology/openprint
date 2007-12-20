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

package openprint::Estimating::SpinePaste;
use strict;

require openprint::service;
require sql;

my @variables = (
'chkOverrideCalliper',
'txtCalliper',
        'ddmEquipment1', 'ddmEquipment2', 'ddmEquipment3',
        'txtPrice1', 'txtPrice2', 'txtPrice3',
        'txtUnitPrice1', 'txtUnitPrice2', 'txtUnitPrice3',
        'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
        'txtRunTime1', 'txtRunTime2', 'txtRunTime3',
        );
sub variables {
    return @variables;
}

sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();

	if ( $services{'NoBindery'} ) {
        $log->debug(" ** Project is marked as No bindery, Hand Assembly not needed ! ** ");
        return 0;
    } # end if

	my $printing_specs = openprint::service::get_specs_ref( $project_index, $services{''}[0] );

    if ( $$printing_specs{'rdbTemplateType'} eq 'SpinePaste' ) {
        return 1;
	} # end if

	return 0;	
} # end sub neccessary

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );

	if ( $$specs{'chkOverrideCalliper'} ne 'Y' ) {
		$$specs{'txtCalliper'} = 0;
		foreach my $signature_service_index ( $Project->signatures('Interior Spreads') ) {
			my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
			my $calliper = $$sig_specs{'txtSignatureSpreadQuantity'} ? $$sig_specs{'txtSignatureSpreadQuantity'} * $$sig_specs{'txtSpecificStockCalliper'} : $$sig_specs{'txtSpecificStockCalliper'};
			$$specs{'txtCalliper'} += $calliper * $$sig_specs{'txtSpreadSize'}/2;
		} # end foreach
	} # end if

	my $equipment;
	my @Equipment = openprint::Equipment::find('strid'=>'PerfectBinder');
	if ( ! @Equipment ) {
		$$specs{'alert'} .= 'We are unable to automatically provide a price for Spine Pasting.  You may enter your own price in the price fields, or contact your CSR for a quote.';

		foreach my $qty_index ( 1 ..3 ) {
			$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
			my $qty = $$specs{'txtQuantity'.$qty_index};
			if ( $qty and ! $$specs{'txtPrice'.$qty_index} ) {
				return $$specs{'Status'} = 'uncalculated';
			} # end if
		} # end foreach
		
		return 'calculated';
	} # end if

	$equipment = $Equipment[0];
	
	my $valid_price = 0;
	foreach my $qty_index ( 1 ..3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{'txtQuantity'.$qty_index};
		next if ! $qty;

		my $price = 0;
		my $unitPrice = 0;
		my $additionalPrice = 0;

		my %servicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'SpinePaste', $qty, $equipment );
		$$specs{'hdnBreakdown'.$qty_index} .= "Service Price: \$ $servicePrice{'Price'} $servicePrice{'units'}\n";
		my $servicePrice;
		if ( $servicePrice{'units'} eq 'Per M' ) {
			$servicePrice = $servicePrice{'Price'} / 1000;
		} # end if
		my $makeReady =  openprint::service::get_price( $log, $dbh, $variable, 'SpinePasteMakeReady', $qty, $equipment );
		$$specs{'hdnBreakdown'.$qty_index} .= "MakeReady: \$ $makeReady\n";
		$price = $servicePrice * $qty + $makeReady;
		$unitPrice = $servicePrice;

		$valid_price = 1 if ( $price > 0 );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $unitPrice );
    } # end foreach

	if ( $valid_price == 0 ) {
		$status = 'uncalculated';
	} # end if

	$log->debug(" END Spine Paste!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

sub summary {
} # end sub summary

1;

__END__
