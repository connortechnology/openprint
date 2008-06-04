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
	my ( $Project, $sig_specs ) = @_;
	my $services = $Project->services();
	return 0 if $$services{'NoPrinting'};
	return 1 if $$sig_specs{'rdbSuppliedStock'} ne 'Y';
	return 0;
} # end sub

sub neccessary {
	my ( $log, $dbh, $project_index ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();
	return 0 if $$services{'NoPrinting'};

    foreach my $signature_service_index ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
        if ( signature_needs( $Project, $sig_specs ) ) {
            return 1;
        } # end if
    } # end foreach
	return 0;
} # end sub neccessary

sub sheet_calc {
	my ( $Paper, $quantity ) = @_;
	my %price;

	my %paper_price = $Paper->get_price( $quantity );
#$openprint::log->warn("Paper Price: qty:($quantity) 100lb Price: $paper_price{'100lb Price'}");
	$price{'100lb Cost'} = $paper_price{'100lb Cost'};
	$price{'100lb Price'} = $paper_price{'100lb Price'};
	$price{'Sheet Cost'} = $paper_price{Cost};
	$price{'Sheet Price'} = $paper_price{Price};
#$openprint::log->warn(" Paper Price: $quantity $paper_price{'100lb Price'} ");

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
	my ( $log, $dbh, $variable, $project_index, $service_index, $sig_specs, $qty_index, $Paper ) = @_;

	$Paper = openprint::Paper::load_from_signature( new openprint::Project($project_index), $sig_specs, $qty_index ) if ! $Paper;

	return sheet_calc( $Paper, $$sig_specs{'txtPressSheetQty'.$qty_index} );
} # end sub signature_calc

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	delete $$specs{'txtPrice1'};
	delete $$specs{'txtPrice2'};
	delete $$specs{'txtPrice3'};

	my $Project = new openprint::Project( $project_index );

	my %totals;
	my %papers;
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		foreach my $qty_index ( 1 .. 3 ) {
			next if ! $Project->quantity( $qty_index );
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
#$openprint::log->warn("Paper Price Override: $$Paper{Price}");
			$papers{$Paper->id()} = $Paper;
			#my $string = sprintf( '%s %s %s %s', $Paper->name(), $Paper->finish(), $Paper->colour(), $Paper->weight() );
			if ( $Paper->type() eq 'Roll' ) {
				#$string .= sprintf(' %s&quot; Roll', $Paper->width() );
				my $impressions = $$sig_specs{'hdnImpressionQuantity'.$qty_index};
				$impressions /= 2 if sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble','Sheet Work'] );
				$totals{$$Paper{id}}[$qty_index] += sprintf('%.0f', $impressions * $Paper->area() * $Paper->wpsi());
			} elsif ( $Paper->type() eq 'Sheet' ) {
				#$string .= sprintf(' %s&quot;x%s&quot;', $Paper->width(), $Paper->height() );
				$totals{$$Paper{id}}[$qty_index] += $$sig_specs{'SheetQuantity'.$qty_index};
			} # end if
		} # end foreach qty_index
	} # end foreach signature
	foreach my $qty_index ( 1 .. 3 ) {
		next if ! $Project->quantity( $qty_index );
		foreach my $paper_id ( keys %totals ) {
			my $Paper = $papers{$paper_id};
			my %price = sheet_calc( $Paper, $totals{$$Paper{id}}[$qty_index] );
#$openprint::log->warn("Paper price for " . $totals{$$Paper{id}}[$qty_index] . ' of ' . $Paper->to_string() . ' : ' . $price{'Paper Price'} );
			$$specs{"txtPrice$qty_index"} += $price{'Paper Price'};
		} # end foreach Stock
	} # end foreach qty_index

	return $$specs{'Status'} = 'calculated';
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

sub summary {
    my ( $Project, $service_id, $specs, $qty_index ) = @_;

    $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

    my %totals;
    my %sheets;
	foreach my $ss_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		foreach my $qty_index ( 1 .. 3 ) {
            next if ! $Project->quantity( $qty_index );
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			my $string = sprintf( '%s %s %s %s', $Paper->name(), $Paper->finish(), $Paper->colour(), $Paper->weight() );
			if ( $Paper->type() eq 'Roll' ) {
				$string .= sprintf(' %s&quot; Roll', $Paper->width() );
				my $impressions = $$sig_specs{'hdnImpressionQuantity'.$qty_index};
				$impressions /= 2 if sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble','Sheet Work'] );
				$totals{$string}[$qty_index] += sprintf('%.0f', $impressions * $Paper->area() * $Paper->wpsi());
					
			} elsif ( $Paper->type() eq 'Sheet' ) {
				$string .= sprintf(' %s&quot;x%s&quot;', $Paper->width(), $Paper->height() );
                $totals{$string}[$qty_index] += sprintf('%.0f', $$sig_specs{'SheetQuantity'.$qty_index} * $Paper->area() * $Paper->wpsi() );
                $sheets{$string}[$qty_index] += $$sig_specs{'SheetQuantity'.$qty_index};
            } # end if
        } # end foreach qty_index

    } # end foreach
	if ( $qty_index ) {
		my $html = '';
		foreach my $key ( sort keys %totals ) {
			if ( $totals{$key}[$qty_index] ) {
				if ( $sheets{$key} ) {
					$html .= $sheets{$key}[$qty_index].'sheets '.$totals{$key}[$qty_index].'lbs';
				} else {
					$html .= $totals{$key}[$qty_index].'lbs';
				} # end if
			} else {
				$html .= 'none';
			} # end if
				$html .= '<br/>';
		} # end foreach key
		return $html;
	} else {
		return join('<br/>', sort keys %totals );
	} # end if
} # end sub summary

1;
__END__
