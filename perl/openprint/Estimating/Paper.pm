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

package openprint::Estimating::Paper;

use strict;

require sql;
require openprint::print;
require openprint::service;
require openprint::Currency;

my @variables = (
        'txtPrice1', 'txtPrice2', 'txtPrice3',
        'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
);

sub variables {
	return @variables;
}

sub signature_needs {
	my ( $log, $dbh, $project_index, $specs ) = @_;
	return 1 if $$specs{'rdbSuppliedStock'} ne 'Y';
	return 0;
} # end sub

sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );

    foreach my $signature_service_index ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
        if ( signature_needs( $log, $dbh, $project_index, $sig_specs ) ) {
            return 1;
        } # end if
    } # end foreach
	return 0;
} # end sub neccessary

sub sheet_calc {
	my ( $Paper, $quantity ) = @_;
	my %price;

	my %paper_price = $Paper->get_price( $quantity );
	$price{'100lb Cost'} = $paper_price{'100lb Cost'};
	$price{'100lb Price'} = $paper_price{'100lb Price'};
	$price{'Sheet Cost'} = $paper_price{Cost};
	$price{'Sheet Price'} = $paper_price{Price};

	if ( $Paper->type() eq 'Roll' ) {
		$price{'Paper Cost'} = sprintf( '%.2f', $quantity/100 * $price{'100lb Cost'} );
		$price{'Paper Price'} = sprintf( '%.2f', $quantity/100 * $price{'100lb Price'} );
	} else {
		$price{'Paper Cost'} = sprintf( '%.2f', $quantity * $price{'Sheet Cost'} );
		$price{'Paper Price'} = sprintf( '%.2f', $quantity * $price{'Sheet Price'} );
	} # end if
	return %price;
} # end sub sheet_calc

sub signature_calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs, $qty_index, $Paper ) = @_;

$openprint::log->debug("Paper Signature Calc");

	if ( ! $Paper ) {
		if ( $$specs{'rdbSuppliedStock'} eq 'Y' ) {
			$log->debug("Supplied");
			$Paper = new openprint::Paper( );
			@$Paper{'cut_paper','perfecting','calliper','Per M'} = ( 'Y','N',@$specs{'txtSpecificStockCalliper','txtCustomSheetPrice'});
			@$Paper{'width','height','mweight'} = @$specs{'txtSpecificStockWidth','txtSpecificStockHeight','txtCustomMWeight'};
			@$Paper{'start_width','start_height'} = @$Paper{'width','height'};
		} else {
			$log->debug("Not Supplied $specs $$specs{'ddmStockBrand'}");
			my @Papers = openprint::Paper::find( 'name'=>$$specs{'ddmStockBrand'}, 'finish'=>$$specs{'ddmStockFinish'}, 'colour'=>$$specs{'ddmStockColour'}, 'weight'=>$$specs{'ddmStockWeight'} );
			foreach my $P ( @Papers ) {
	#$log->debug("Looking at: " . $Sheet->width() . ' x '. $Sheet->height() . " for ".$$specs{'hdnSuppliedStockWidth'.$qty_index}.'x'.$$specs{'hdnSuppliedStockHeight'.$qty_index});
				if ( $P->width() == $$specs{'hdnSuppliedStockWidth'.$qty_index} and $P->height() == $$specs{'hdnSuppliedStockHeight'.$qty_index} ) {
					$Paper = $P;
					$log->debug("Found sheet");
					last;
				} # end if
			} # end foreach
			if ( $Paper ) {
				my ( $width, $height ) = split('x', $$specs{'ddmStockSheetSize'.$qty_index} );
				while ( $Paper->width() > $width or $Paper->height() > $height ) {
					$Paper->cut();
				} # end while
			} # end if
		} # end if
	} # end if

	return sheet_calc( $Paper, $$specs{'txtPressSheetQty'.$qty_index} );
} # end sub

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	delete $$specs{'txtPrice1'};
	delete $$specs{'txtPrice2'};
	delete $$specs{'txtPrice3'};

	my $Project = new openprint::Project( $project_index );

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		foreach my $qty_index ( 1 .. 3 ) {
			next if ! $$sig_specs{'txtQuantity'.$qty_index};
			my %price = signature_calc( $log, $dbh, $variable, $project_index, $signature_service_index, $sig_specs, $qty_index );
			$$specs{'txtPrice'.$qty_index} += $price{'Paper Price'};
			
		} # end foreach qty_index
	} # end foreach
	$$specs{'Status'} = 'calculated';
	return 'calculated';
} # end sub calc

sub display {
	my ( $self, $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my %totals;
	my $Project = new openprint::Project( $project_index );

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $project_index, $signature_service_index );
		next if $$sig_specs{'rdbSuppliedStock'} eq 'Y';
		foreach my $qty_index ( 1 .. 3 ) {

			my $brand = $$sig_specs{'txtSpecificStockBrand'} ? $$sig_specs{'txtSpecificStockBrand'} : $$sig_specs{'ddmStockBrand'};
			my $colour = $$sig_specs{'txtSpecificStockColour'} ? $$sig_specs{'txtSpecificStockColour'} : $$sig_specs{'ddmStockColour'};
			my $finish = $$sig_specs{'txtSpecificStockFinish'} ? $$sig_specs{'txtSpecificStockFinish'} : $$sig_specs{'ddmStockFinish'};
			my $weight = $$sig_specs{'txtSpecificStockWeight'} ? $$sig_specs{'txtSpecificStockWeight'} : $$sig_specs{'ddmStockWeight'};

			my $id = $qty_index.$brand.$colour.$finish.$weight.$$sig_specs{'hdnSuppliedSheetSizeWidth'.$qty_index}.'x'.$$sig_specs{'hdnSuppliedSheetSizeHeigth'.$qty_index};

			if ( ! exists $totals{$id} ) {
				$totals{$id}{Brand} = $brand;
				$totals{$id}{Colour} = $colour;
				$totals{$id}{Finish} = $finish;
				$totals{$id}{Weight} = $weight;
				$totals{$id}{SheetSize} = $$sig_specs{'hdnSuppliedSheetSizeWidth'.$qty_index} . ' x ' . $$sig_specs{'hdnSuppliedSheetSizeHeight'.$qty_index};
			} # end if

			$totals{$id}{'SheetCount'} += $$sig_specs{'txtPressSheetqty'.$qty_index};
		} # end foreach qty
	} # end foreach signature

	foreach my $qty_index ( 1 .. 3 ) {
		foreach my $id ( keys %totals ) {
			my ( $price, $discount );

			if ( $totals{$id}{Index} ) {
				my $list_id = openprint::pricing::get_pricelist_id( $log, $dbh, $variable );
				$price = openprint::pricing::get_best_price( $log, $dbh, $$variable{'cust_id'}, $totals{$id}{Index}, $list_id, 'openprint::paper_priceset', 1 );
				my $discounted_price = openprint::pricing::get_best_price( $log, $dbh, $$variable{'cust_id'}, $totals{$id}{Index}, $list_id, 'openprint::paper_priceset', $totals{$id}{'hdnGrossSheetCount'.$qty_index} );
				$discount = $price - $discounted_price;
			} # end if

			push @{$$variable{'PAPER'.$qty_index}}, $totals{$id}{Brand}, $totals{$id}{Colour}, $totals{$id}{Finish}, $totals{$id}{Weight}, $totals{$id}{SheetSize};
			push @{$$variable{'PAPER'.$qty_index}}, $totals{$id}{'hdnGrossSheetCount'.$qty_index}, sprintf('%.2f',$price), sprintf('%.2f',$discount);
		} # end foreach
	} # end foreach

	my $Currency = openprint::Currency::get_current();
	@$variable{'CurrencyName', 'CurrencySymbol'} = ( $Currency->name(), $Currency->symbol() );
    $$variable{'ProjectIndex'} = $project_index;

} # end sub display

1;
__END__
