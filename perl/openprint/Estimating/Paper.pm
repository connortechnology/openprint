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

my $debug = 0;

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
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, "qty-$stock_index-$qty_index";
			push @v, "sheets-$stock_index-$qty_index";
		} # end foreach qty_index
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

	# Totals is storing the native qty, ie lbs for rolls, sheets for sheets
	my %totals;
	my %papers;
    my %indexes;

	# FIrst pass: figure out the quantities involved, so that in the second pass, we can lookup prices based on quantity discounts.
	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );

        # What we do is load each stock for the signature, and assign it a stock_index, 1 .. 4, then deal with them in order.
        foreach my $qty_index ( $Project->quantity_indexes() ) {
			next if ! $$sig_specs{'txtImposition'.$qty_index};
            my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			my $Supplied = $Paper->Supplied();
            $papers{$Supplied->to_string()} = $Supplied;
        } # end foreach
	} # end foreach signature

	my @stocks = sort keys %papers;
	foreach my $stock_index ( 1 .. @stocks ) {
		my $paper_string = $stocks[$stock_index-1];
		$indexes{$paper_string} = $stock_index;
$openprint::log->debug("Indexes: $paper_string => $stock_index") if $debug;
	} # end foreach

	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );

		foreach my $qty_index ( $Project->quantity_indexes() ) {
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			my $PressSheet = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			# This paper is in the printing format, not the supplied
			# Convert to supplied Stock
			my $SuppliedStock = $PressSheet->Supplied();
			my $paper_string = $SuppliedStock->to_string();

			my $stock_index = $indexes{$paper_string};

			if ( $$specs{"overrideqty-$ss_id-$stock_index-$qty_index"} ne 'Y' ) {
				if ( $PressSheet->type() eq 'Sheet' ) {
					my $sheets = $$sig_specs{'StockQuantity'.$qty_index};
					# convert to supplied count
					$sheets = ceil( $sheets / ( $PressSheet->start_area()/$PressSheet->area() ) );
					$$specs{"qty-$ss_id-$stock_index-$qty_index"} = ceil( $sheets * $PressSheet->start_sheet_weight() );
					$$specs{"sheets-$ss_id-$stock_index-$qty_index"} = $sheets;
				} else {
					$$specs{"qty-$ss_id-$stock_index-$qty_index"} = $$sig_specs{'StockQuantity'.$qty_index};
					delete $$specs{"sheets-$ss_id-$stock_index-$qty_index"};
				} # end if
			} # end if

			if ( $SuppliedStock->type() eq 'Sheet' ) {
				$totals{$paper_string}{"qty_$qty_index"} += $$specs{"sheets-$ss_id-$stock_index-$qty_index"};
			} else {
				$totals{$paper_string}{"qty_$qty_index"} += $$specs{"qty-$ss_id-$stock_index-$qty_index"};
			} # end if
		} # end foreach qty_index
	} # end foreach signature

if ( $debug ) {
$openprint::log->debug('Total Paper Totals:');
	foreach my $paper_string ( keys %papers ) {
		my $Paper = $papers{$paper_string};
		foreach my $qty_index ( $Project->quantity_indexes() ) {
$openprint::log->debug("QTY $qty_index ($paper_string) => " . $totals{$paper_string}{"qty_$qty_index"} );
		} # end foreach
	} # end if
} # end if
	# Enforce minimum orders and full packages
	foreach my $paper_string ( keys %papers ) {
		my $Paper = $papers{$paper_string};
		if ( $Paper->full_packages() ) {
			my $sheets_per_package = $Paper->sheets_per_package();
			if ( $sheets_per_package ) {
				foreach my $qty_index ( $Project->quantity_indexes() ) {
					next if ! $totals{$paper_string}{"qty_$qty_index"};
					if ( $Paper->type() eq 'Sheet' ) {
						$totals{$paper_string}{"qty_$qty_index"} = $sheets_per_package * ceil( $totals{$paper_string}{"qty_$qty_index"} / $sheets_per_package );
					} elsif ( $Paper->type() eq 'Roll' ) {
						$totals{$paper_string}{"qty_$qty_index"} = $sheets_per_package * ($totals{$paper_string}{"qty_$qty_index"}/$sheets_per_package);
					} # end if
				} # end foreah qty_index
			} # end if sheets_per_package
		} # end if full packages
		if ( $$Paper{'minimum_order'} ) {
# Assume sheets for sheets, lbs for Rolls
			foreach my $qty_index ( $Project->quantity_indexes() ) {
				next if ! $totals{$paper_string}{"qty_$qty_index"};
				if ( $$Paper{'minimum_order'} > $totals{$paper_string}{"qty_$qty_index"} ) {
					$totals{$paper_string}{"qty_$qty_index"} = $$Paper{'minimum_order'};
				} # end if
			} # end foreach qty_index
		} # end if
	} # end foreach

	foreach my $paper_string ( keys %papers ) {
		my $Paper = $papers{$paper_string};
		foreach my $qty_index ( $Project->quantity_indexes() ) {
#$openprint::log->debug("After minimum: QTY $qty_index $paper_string  => " . $totals{$paper_string}[$qty_index] );
		} # end foreach
	} # end if

	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			# We are doing this because we calculate on the parent sheet, but if the parent sheet is a generic... then it all goes for shit.
			my $RunPaper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			my $Paper = $RunPaper->Supplied();
			my $paper_id = $Paper->to_string();
			my $stock_index = $indexes{$paper_id};
			next if $Paper->supplied();

			if ( $$specs{"overridecost-$ss_id-$stock_index-$qty_index"} ne 'Y' ) {
				my $price;
				if ( $Paper->type() eq 'Sheet' ) {
					$price = $Paper->get_price( 'weight'=>$totals{$paper_id}{"qty_$qty_index"} * $Paper->sheet_weight(),'service'=>'Material' );
				} else {
					$price = $Paper->get_price( 'weight'=>$totals{$paper_id}{"qty_$qty_index"},'service'=>'Material' );
				} # end if
				$$specs{"cost-$ss_id-$stock_index-$qty_index"} = $$price{'100lb Price'};
#$openprint::log->warn("Getting prices for $stock_index $paper_id (".$totals{$paper_id}{"qty_$qty_index"}.'sheets) => $' . $price{'100lb Price'}.'/100lb');
			} # end if
			$$specs{"price-$ss_id-$stock_index-$qty_index"} = sprintf($openprint::config{'UnitPriceFormat'},$$specs{"cost-$ss_id-$stock_index-$qty_index"} * $$specs{"qty-$ss_id-$stock_index-$qty_index"} / 100 );
			#if ( $Paper->type() eq 'Sheet' ) {
				$totals{$paper_id}{"Cost"} = $$specs{"cost-$ss_id-$stock_index-$qty_index"};
				#$$specs{"txtPrice$qty_index"} += $$specs{"cost-$ss_id-$stock_index-$qty_index"} * $$specs{"qty-$ss_id-$stock_index-$qty_index"} / 100;
			#} else {
				#$$specs{"txtPrice$qty_index"} += $$specs{"cost-$ss_id-$stock_index-$qty_index"} * $totals{$paper_id}[$qty_index] / 100;
			#} # end if
#$openprint::log->warn("$qty_index $paper_id $$sig_specs{'txtImposition'.$qty_index} $$Paper{width}x$$Paper{height}" . ' : ' . $Paper->start_sheet_weight() );
			$$specs{"MPrice$qty_index"} += $$specs{"cost-$ss_id-$stock_index-$qty_index"} * ceil( (1000/$$sig_specs{'txtImposition'.$qty_index}) * $RunPaper->sheet_weight() )/ 100;
		} # end foreach qty_index
	} # end foreach signature

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		my $stock_index = 1;
		$$specs{"txtPrice$qty_index"} = 0;
		foreach my $paper_id ( sort keys %papers ) {
			my $Paper = $papers{$paper_id};
$openprint::log->debug($paper_id . ' => ' . $totals{$paper_id}{"qty_$qty_index"} ) if $debug;
			if ( $Paper->type() eq 'Sheet' ) {
				$$specs{"qty-$stock_index-$qty_index"} = ceil( $totals{$paper_id}{"qty_$qty_index"} * $Paper->sheet_weight() );
				$$specs{"sheets-$stock_index-$qty_index"} = $totals{$paper_id}{"qty_$qty_index"};
			} else {
				$$specs{"qty-$stock_index-$qty_index"} = $totals{$paper_id}{"qty_$qty_index"};
				$$specs{"sheets-$stock_index-$qty_index"} = ceil( $totals{$paper_id}{"qty_$qty_index"} / $Paper->start_sheet_weight() ) if $Paper->start_sheet_weight();
			} # end if
			$$specs{"txtPrice$qty_index"} += $$specs{"qty-$stock_index-$qty_index"} * $totals{$paper_id}{"Cost"} / 100;
			$stock_index += 1;
		} # end foreach Stock
		$$specs{"MPrice$qty_index"} = sprintf($openprint::config{'UnitPriceFormat'}, $$specs{"MPrice$qty_index"} * (1+$Project->markup()/100) );
		$$specs{"txtPrice$qty_index"} = sprintf($openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} * (1+$Project->markup()/100) );
$openprint::log->debug("Price $qty_index " . $$specs{"txtPrice$qty_index"} ) if $debug;
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

    my %Papers;
	foreach my $ss_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			# Convert back to original size
			@$Paper{'width','height'} = @$Paper{'start_width','start_height'};
			$Paper->mweight(0); # force recalc
			$Papers{$Paper->to_string()} = $Paper;
        } # end foreach qty_index
    } # end foreach

	if ( $qty_index ) {
		my @summaries;
		my $stock_id = 1;
		foreach my $key ( sort keys %Papers ) {
			my $html = '';
			my $Paper = $Papers{$key};
#$openprint::log->warn("Stock QTY $stock_id $qty_index " . $$specs{"qty-$stock_id-$qty_index"} );
			if ( $$specs{"qty-$stock_id-$qty_index"} ) {
				if ( $Paper->type() eq 'Sheet' ) {
					$html .= $$specs{"sheets-$stock_id-$qty_index"}.'sheets ';
				} # end if
				$html .= $$specs{"qty-$stock_id-$qty_index"}.'lbs';
				if ( sets::isin( $Project->Type()->name(), [ 'Banners' ] ) ) {
					$html .= sprintf(' %.0finches',( $$specs{"qty-$stock_id-$qty_index"} / $Paper->wpsi() ) / $Paper->width() );
				} # end if
			} else {
				$html .= 'none';
			} # end if
			push @summaries, $html;
			$stock_id += 1;
		} # end foreach key
		return \@summaries;
	} # end if
	return [ sort keys %Papers ];
} # end sub summary

sub save {
} # end sub save

1;
__END__
