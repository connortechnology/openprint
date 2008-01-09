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

package openprint::Estimating::PerfectBound;
use strict;

require openprint::service;
require sql;

my %variables = (
        'ProjectIndex'=>[],'ServiceIndex'=>[],
        'hdnBreakdown1'=>['output'],'hdnBreakdown2'=>['output'],'hdnBreakdown3'=>['output'],
        'txtQuantity1'=>['save'], 'txtQuantity2'=>['save'], 'txtQuantity3'=>['save'],
        'ServiceType'=>[],
        'alert'=>['output'],
        'txtInsertQuantity'=>['save','output'],'chkOverrideInsertQuantity'=>['save'],
        'txtCalliper'=>['save','output'],
        'Imposition1'=>['save','output'], 'Imposition2'=>['save','output'], 'Imposition3'=>['save','output'],
        'ddmEquipment1'=>['save','output'], 'ddmEquipment2'=>['save','output'], 'ddmEquipment3'=>['save','output'],
        'OverridePockets1'=>['save'], 'OverridePockets2'=>['save'], 'OverridePockets3'=>['save'],
        'chkOverrideEquipment1'=>['save'], 'chkOverrideEquipment2'=>['save'], 'chkOverrideEquipment3'=>['save'],
        'rdbGateFoldFit'=>['save'],
        'txtUnitPrice1'=>['output'], 'txtUnitPrice2'=>['output'], 'txtUnitPrice3'=>['output'],
        'txtPrice1'=>['save','output'], 'txtPrice2'=>['save','output'], 'txtPrice3'=>['save','output'],
        'txtRunTime1'=>['save'], 'txtRunTime2'=>['save'], 'txtRunTime3'=>['save'],
        );

sub variables {
	my ( $p_id, $s_id, $specs ) = @_;
    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k, if sets::isin( 'save', $variables{$k} );
    } # end foreach;
    if ( int $$specs{'txtInsertQuantity'} ) {
        foreach my $insert_id ( 1 .. int $$specs{'txtInsertQuantity'} ) {
            push @v, 'txtInsertPage1-'.$insert_id, 'txtInsertPage2-'.$insert_id;
        } # end foreach
    } # end if
	foreach my $qty_index ( 1 .. 3 ) {
		foreach my $k ( 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40 ) {
			push @v, 'txtSignatureQty'.$k.'Page-'.$qty_index;
		} # end foreach
	} # end foreach

    return @v;
} # end sub variables

sub neccessary {
	my ( $Project ) = @_;

	my $services = $Project->services();

	if ( $$services{'NoBindery'} ) {
        return 0;
    } # end if

	my $printing_specs = openprint::service::get_specs_ref( $Project, $$services{''}[0] );

    if ( $$printing_specs{'rdbTemplateType'} eq 'PerfectBound' ) {
        return 1;
	} # end if

	return 0;	
} # end sub neccessary

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	if ( ! $$services{'Folding'} ) {
		$$specs{'alert'} .= 'Project must be folded.<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	my $folding_specs = openprint::service::get_specs_ref( $Project, $$services{'Folding'}[0] );

	if ( $$specs{'chkOverrideCalliper'} ne 'Y' ) {
		foreach my $qty_index ( 1 .. 3 ) {
			$$specs{'txtCalliper'} = 0;
			foreach my $signature_service_index ( $Project->signatures('Interior Pages') ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
				my $calliper = $$sig_specs{'PageQuantity'.$qty_index} ? ($$sig_specs{'PageQuantity'.$qty_index}/2) * $$sig_specs{'txtSpecificStockCalliper'} : $$sig_specs{'txtSpecificStockCalliper'};
				$$specs{'txtCalliper'} += $calliper;
			} # end foreach
			last if $$specs{'txtCalliper'};
		} # end foreach
	} # end if

	foreach my $qty_index ( 1 .. 3 ) {
		next if ! $$specs{'txtQuantity'.$qty_index};
		$$specs{'txtPrice'.$qty_index} = '0.00';
		$$specs{'txtUnitPrice'.$qty_index} = '0.00';
		$$specs{'hdnBreakdown'.$qty_index} .= 'Finished Calliper: ' . $$specs{'txtCalliper'} . '<br/>';
		$$specs{'hdnBreakdown'.$qty_index} .= 'Face Trim: ' . $$specs{'Width'} . '<br/>';

		if ( $$specs{'OverridePockets'.$qty_index} ne 'Y' ) {
			foreach my $pages ( 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48 ) {
				$$specs{'txtSignatureQty'.$pages.'Page-'.$qty_index} = '';
			} # end foreach
			foreach my $signature_service_index ( $Project->signatures() ) {
				my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );

				if ( ! $$sig_specs{'txtImposition'.$qty_index} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Signature $$sig_specs{SignatureIndex} has no imposition.<br/>";
					next;
				} # end if
				if ( ! $$sig_specs{'txtSpreadSize'} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Signature $$sig_specs{SignatureIndex} has no spread size.<br/>";
					next;
				} # end if
				if ( ! $$sig_specs{'PageQuantity'.$qty_index} ) {
					$$specs{'hdnBreakdown'.$qty_index} .= "Signature $$sig_specs{SignatureIndex} has no pages.<br/>";
					next;
				} # end if

				if ( $folding_specs ) {
					foreach my $pages ( 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48 ) {
						my $pockets = $$folding_specs{$pages.'PageSignatureFold-Qty-'.$$sig_specs{'SignatureIndex'}.'-'.$qty_index};
						$$specs{'txtSignatureQty'.$pages.'Page-'.$qty_index} += $pockets;
						$$specs{"txtPockets$qty_index"} += $pockets;
					} # end foreach
				} else {
					my $sig_size = $$sig_specs{'PageQuantity'.$qty_index};
					$$specs{"txtPockets$qty_index"} += 1;
					$$specs{'txtSignatureQty'.$sig_size.'Page-'.$qty_index} += 1;
				} # end if
			} # end foreach signature
		} else { # Override Pockets
			foreach my $pages ( 2, 4, 6, 8, 10, 12, 14, 16, 18, 20, 22, 24, 26, 28, 30, 32, 34, 36, 38, 40, 42, 44, 46, 48 ) {
				$$specs{"txtPockets$qty_index"} += $$specs{'txtSignatureQty'.$pages.'Page-'.$qty_index};
			} # end foreach
		} # end if
	} # end foreach qty_index

	my $equipment;
	my @Equipment = openprint::Equipment::find('strid'=>'PerfectBinder','use_in_estimating'=>'Y');
	if ( ! @Equipment ) {
		$$specs{'alert'} .= 'We are unable to automatically provide a price for Perfect Binding.  You may enter your own price in the price fields, or contact your CSR for a quote.';
		foreach my $qty_index ( 1 ..3 ) {
			$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
			my $qty = $$specs{'txtQuantity'.$qty_index};
			if ( $qty and ! $$specs{'txtPrice'.$qty_index} ) {
				return $$specs{'Status'} = 'uncalculated';
			} # end if
		} # end foreach

		return $$specs{'Status'} = 'calculated';
	} # end if

	$equipment = $Equipment[0];
	if ( $equipment->specification('Maximum Calliper') and $equipment->specification('Maximum Calliper') < $$specs{'txtCalliper'} ) {
		$$specs{'alert'} .= 'Project is too thick for our equipment. Maximum thickness is ' . $equipment->specification('Maximum Calliper');
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( $equipment->specification('Minimum Calliper') and $equipment->specification('Minimum Calliper') > $$specs{'txtCalliper'} ) {
		$$specs{'alert'} .= 'Project is too thin for our equipment. Minimum thickness is ' . $equipment->specification('Minimum Calliper');
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	
	my $valid_price = 0;
	foreach my $qty_index ( 1 ..3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		my $qty = $$specs{'txtQuantity'.$qty_index};
		next if ! $qty;

		my $price = 0;
		my $unitPrice = 0;
		my $additionalPrice = 0;

		my %servicePrice;
		if ( ! ( %servicePrice = openprint::service::get_price_object( 'PerfectBound'.$$specs{'txtPockets'.$qty_index}.'Pockets', $qty, $equipment ) ) ) {
			%servicePrice = openprint::service::get_price_object( 'PerfectBound', $qty, $equipment );
		} # end if
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('Service Price: $%.2f%s<br/>', @servicePrice{'Price','units'} );
		if ( $servicePrice{'units'} eq 'Per M' ) {
			$servicePrice{'Total'} = $qty * $servicePrice{'Price'} / 1000;
		} else {
			$openprint::log->error('Unknown units in service price');
		} # end if
		my $makeReady = openprint::service::get_price( 'PerfectBoundMakeReady', $$specs{'txtPockets'.$qty_index}, $equipment );
		$$specs{'hdnBreakdown'.$qty_index} .= sprintf('MakeReady: $%.2f<br/>', $makeReady );
		$price = $servicePrice{'Total'} + $makeReady;

		$valid_price = 1 if ( $price > 0 );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $price/ $qty );
    } # end foreach

	if ( $valid_price == 0 ) {
		$status = 'uncalculated';
	} # end if

	$log->debug(" END Perfect Bound!!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

sub summary {
} # end sub summary

1;

__END__
