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
use POSIX qw( ceil );

require sql;
require openprint::print;
require openprint::service;
require openprint::Currency;
require openprint::Estimating::Printing;

my $debug = 1;

my @variables = (
        'txtPrice1', 'txtPrice2', 'txtPrice3',
		'MPrice1','MPrice2','MPrice3',
        'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
		'hdnBreakdown1','hdnBreakdown2','hdnBreakdown3',
);

sub variables {
	my ( $p_id, $s_id, $specs ) = @_;
	my @v = @variables;

	my $Project = new openprint::Project( $p_id );
	foreach my $ss_id ( $Project->signatures() ) {
		foreach my $stock_index ( 1 .. 4 ) {
			last if ! $$specs{"id-$ss_id-$stock_index"};
			push @v, "id-$ss_id-$stock_index";
			foreach my $qty_index ( $Project->quantity_indexes() ) {
				push @v, "qty-$ss_id-$stock_index-$qty_index";
				push @v, "sheets-$ss_id-$stock_index-$qty_index";
				push @v, "overrideqty-$ss_id-$stock_index-$qty_index";
				push @v, "cost-$ss_id-$stock_index-$qty_index";
				push @v, "overridecost-$ss_id-$stock_index-$qty_index";
				push @v, "price-$ss_id-$stock_index-$qty_index";
			} # end foreach qty_index
		} # end foreach stock_index
	} # end foreach ss_id
	foreach my $stock_index ( 1 .. 4 ) {
		push @v, "totalqty-$stock_index";
	} # end foreach stock_index
	return @v;
} # end sub variables

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

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $Project = new openprint::Project( $project_index );
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		delete $$specs{'txtPrice'.$qty_index};
		delete $$specs{'MPrice'.$qty_index};
	} # end foreach qty_index

	my %totals;
	my %papers;

	# FIrst pass: figure out the quantities involved, so that in the second pass, we can lookup prices based on quantity discounts.
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		foreach my $stock_index ( 1 .. 4 ) {
			last if ( $stock_index > 1 ) and ( ! $$specs{"id-$ss_id-$stock_index"} );

			foreach my $qty_index ( $Project->quantity_indexes() ) {
				next if ! $$sig_specs{'txtImposition'.$qty_index};
				my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
				$papers{$Paper->to_string()} = $Paper;

				if ( $$specs{"overrideqty-$ss_id-$stock_index-$qty_index"} ne 'Y' ) {
					if ( $Paper->type() eq 'Sheet' ) {
						my $sheets = $$sig_specs{'StockQuantity'.$qty_index};
						$sheets /= ( $Paper->start_area() /$Paper->area() );
						$sheets = ceil( $sheets );
	
						$$specs{"qty-$ss_id-$stock_index-$qty_index"} = ceil( $sheets * $Paper->start_area() * $Paper->wpsi() );
						$$specs{"sheets-$ss_id-$stock_index-$qty_index"} = $sheets;
					} else {
						$$specs{"qty-$ss_id-$stock_index-$qty_index"} = $$sig_specs{'StockQuantity'.$qty_index};
						delete $$specs{"sheets-$ss_id-$stock_index-$qty_index"};
					} # end if
				} # end if
			
				$totals{$Paper->to_string()}[$qty_index] += $$specs{"qty-$ss_id-$stock_index-$qty_index"};
			} # end foreach qty_index
		} # end foreach stock_index
	} # end foreach signature

	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		foreach my $stock_index ( 1 .. 4 ) {
			last if ( $stock_index > 1 ) and ( ! $$specs{"id-$ss_id-$stock_index"} );

			foreach my $qty_index ( $Project->quantity_indexes() ) {
				next if ! $$sig_specs{'txtImposition'.$qty_index};
				my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
				my $paper_id = $Paper->to_string();
				next if $Paper->supplied();

				if ( $$specs{"overridecost-$ss_id-$stock_index-$qty_index"} ne 'Y' ) {
					my %price = $Paper->get_price( $totals{$paper_id}[$qty_index] );
					$$specs{"cost-$ss_id-$stock_index-$qty_index"} = $price{'100lb Price'};
				} # end if
				$$specs{"price-$ss_id-$stock_index-$qty_index"} = sprintf($openprint::config{'UnitPriceFormat'},$$specs{"cost-$ss_id-$stock_index-$qty_index"} * $$specs{"qty-$ss_id-$stock_index-$qty_index"} / 100 );
				$$specs{"txtPrice$qty_index"} += $$specs{"price-$ss_id-$stock_index-$qty_index"};
				$$specs{"MPrice$qty_index"} += $$specs{"cost-$ss_id-$stock_index-$qty_index"} * ceil( ((1000/$$sig_specs{'txtImposition'.$qty_index})/( $Paper->start_area() /$Paper->area() )) * $Paper->start_area() * $Paper->wpsi() )/ 100;
			} # end foreach qty_index
		} # end foreach stock_index
	} # end foreach signature

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		foreach my $paper_id ( keys %totals ) {
			my $Paper = $papers{$paper_id};
			$$specs{"qty-$$Paper{id}-$qty_index"} = $totals{$paper_id}[$qty_index];
		} # end foreach Stock
		$$specs{"MPrice$qty_index"} = sprintf($openprint::config{'UnitPriceFormat'}, $$specs{"MPrice$qty_index"} );
		$$specs{"txtPrice$qty_index"} = sprintf($openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
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
		foreach my $qty_index ( $Project->quantity_indexes() ) {

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

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		foreach my $id ( keys %totals ) {
			my ( $price, $discount );

			if ( $totals{$id}{Index} ) {
				my $list_id = openprint::pricing::get_pricelist_id( $log, $dbh, $variable );
				$price = openprint::pricing::get_best_price( $log, $dbh, $$variable{'company_id'}, $totals{$id}{Index}, $list_id, 'openprint::paper_priceset', 1 );
				my $discounted_price = openprint::pricing::get_best_price( $log, $dbh, $$variable{'company_id'}, $totals{$id}{Index}, $list_id, 'openprint::paper_priceset', $totals{$id}{'hdnGrossSheetCount'.$qty_index} );
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
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			my $string = '';
			$string .= 'Customer Supplied ' if $Paper->supplied();
			$string .= sprintf( '%s %s %s %s', $Paper->name(), $Paper->finish(), $Paper->colour(), $Paper->weight() );
			if ( $Paper->type() eq 'Roll' ) {
				$string .= sprintf(' %s&quot; Roll', $Paper->width() );
				
				$totals{$string}[$qty_index] += $$sig_specs{'StockQuantity'.$qty_index};
#$$openprint::log->debug("I: $impressions * $$Paper{width} * $$Paper{height} * " . $Paper->wpsi() . " = " . $totals{$string}[$qty_index] );
					
			} elsif ( $Paper->type() eq 'Sheet' ) {
				$string .= sprintf(' %s&quot;x%s&quot;', $Paper->start_width(), $Paper->start_height() );
				my $sheets = $$sig_specs{'StockQuantity'.$qty_index};
				$sheets /= ( $Paper->start_area() /$Paper->area() );
				$sheets = ceil( $sheets );
                $totals{$string}[$qty_index] += sprintf('%.0f', $sheets * $Paper->start_area() * $Paper->wpsi() );
                $sheets{$string}[$qty_index] += $sheets;
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

sub save {
} # end sub save

1;
__END__
