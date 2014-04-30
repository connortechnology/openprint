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

use constant DEBUG => 0;

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
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		my $form = $$sig_specs{SignatureIndex};
		foreach my $stock_index ( 1 .. 4 ) {
			#last if ! exists $$specs{"qty-$ss_id-$stock_index"};
			#push @v, "id-$ss_id-$stock_index";
			foreach my $qty_index ( $Project->quantity_indexes() ) {
				push @v, "qty-$form-$stock_index-$qty_index";
				push @v, "sheets-$form-$stock_index-$qty_index";
				push @v, "overrideqty-$form-$stock_index-$qty_index";
				push @v, "cost-$form-$stock_index-$qty_index";
				push @v, "overridecost-$form-$stock_index-$qty_index";
				push @v, "price-$form-$stock_index-$qty_index";
			} # end foreach qty_index
		} # end foreach stock_index
	} # end foreach ss_id
	foreach my $stock_index ( 1 .. 4 ) {
		foreach my $qty_index ( $Project->quantity_indexes() ) {
			push @v, "qty-$stock_index-$qty_index";
			push @v, "sheets-$stock_index-$qty_index";
		} # end foreach qty_index
	} # end foreach stock_index
#$openprint::log->debug( "Variables: @v");
	return @v;
} # end sub variables

sub outputs {
}
sub no_outputs {
}

sub signature_needs {
	my ( $Project, $sig_specs ) = @_;
	my $services = $Project->services();
	return 0 if $$services{'NoPrinting'};
	#return 1 if $$sig_specs{'rdbSuppliedStock'} ne 'Y';
	return 1;
} # end sub

sub neccessary {
	my ( $Project ) = @_;

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
			next if ! ( $Paper->id() or $$Paper{custom} );
#$openprint::log->debug("Got Press Sheet for sig $$sig_specs{'SignatureIndex'} qty $qty_index " . $Paper->to_string() );
			my $Supplied = $Paper->Supplied();
#$openprint::log->debug("Got Stock Sheet for sig $$sig_specs{'SignatureIndex'} qty $qty_index " . $Supplied->to_string() );
            $papers{$Supplied->id_string()} = $Supplied;
        } # end foreach
	} # end foreach signature
	if ( ! %papers ) {
		$$specs{alert} .= 'Stocks not found.<br/>';
		return $$specs{Status} = 'uncalculated';
	} # end if
	$$specs{Status} = 'calculated';

	my @stocks = sort keys %papers;
	foreach my $stock_index ( 1 .. scalar @stocks ) {
		my $paper_string = $stocks[$stock_index-1];
		$indexes{$paper_string} = $stock_index;
$openprint::log->debug("Indexes: $paper_string => $stock_index") if DEBUG;
	} # end foreach

	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		my $form = $$sig_specs{SignatureIndex};

		foreach my $qty_index ( $Project->quantity_indexes() ) {
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			my $PressSheet = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			next if ! ( $PressSheet->id() or $$PressSheet{custom} );
			# This paper is in the printing format, not the supplied
			# Convert to supplied Stock
			my $SuppliedStock = $PressSheet->Supplied();
			my $paper_string = $SuppliedStock->id_string();

			my $stock_index = $indexes{$paper_string};
			if ( ! $stock_index ) {
$openprint::log->error("Estimating::Paper No stock index for $paper_string");
$openprint::log->debug("Press sheet: " . $PressSheet->id_string() );
$openprint::log->debug("Supplied: " . $SuppliedStock->id_string() );
			} # end if

			if ( $$specs{"overrideqty-$form-$stock_index-$qty_index"} ne 'Y' ) {
				if ( $PressSheet->type() eq 'Sheet' ) {
					my $sheets = $$sig_specs{'StockQuantity'.$qty_index};
					if ( ! ( $PressSheet->area() and $PressSheet->start_area() ) ) {
						Carp::cluck("No sheet area");
					} else {
					# convert to supplied count
					$sheets = ceil( $sheets / ( $PressSheet->start_area()/$PressSheet->area() ) );
					} # end if
					$$specs{"qty-$form-$stock_index-$qty_index"} = Math::Round::nearest( 0.1, ( $sheets * $PressSheet->start_sheet_weight() ) );
					$$specs{"sheets-$form-$stock_index-$qty_index"} = $sheets;
				} else {
					$$specs{"qty-$form-$stock_index-$qty_index"} = $$sig_specs{'StockQuantity'.$qty_index};
					delete $$specs{"sheets-$form-$stock_index-$qty_index"};
				} # end if
			} # end if

			if ( $SuppliedStock->type() eq 'Sheet' ) {
				$totals{$paper_string}{"qty_$qty_index"} += $$specs{"sheets-$form-$stock_index-$qty_index"};
			} else {
				$totals{$paper_string}{"qty_$qty_index"} += $$specs{"qty-$form-$stock_index-$qty_index"};
			} # end if
		} # end foreach qty_index
	} # end foreach signature

if ( DEBUG ) {
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
						$totals{$paper_string}{"qty_$qty_index"} = $sheets_per_package * Math::Round::nearest(0.1,( $totals{$paper_string}{"qty_$qty_index"} / $sheets_per_package ) );
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
		if ( $$Paper{available_to_order} > 0 ) {
			foreach my $qty_index ( $Project->quantity_indexes() ) {
				next if ! $totals{$paper_string}{"qty_$qty_index"};
				if ( $$Paper{available_to_order} < $totals{$paper_string}{"qty_$qty_index"} ) {
					$$specs{alert}  .= $Paper->to_string() . ' has only ' . $$Paper{available_to_order} . " available. This does not satisfy quantity $qty_index<br/>";
					$$specs{Status} = 'uncalculated';
				} # end if
			} # end foreach
		} # end if
	} # end foreach

if ( 0 ) {
	foreach my $paper_string ( keys %papers ) {
		my $Paper = $papers{$paper_string};
		foreach my $qty_index ( $Project->quantity_indexes() ) {
#$openprint::log->debug("After minimum: QTY $qty_index $paper_string  => " . $totals{$paper_string}[$qty_index] );
		} # end foreach
	} # end if
}

	foreach my $ss_id ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
		my $form = $$sig_specs{SignatureIndex};

		foreach my $qty_index ( $Project->quantity_indexes() ) {
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			# We are doing this because we calculate on the parent sheet, but if the parent sheet is a generic... then it all goes for shit.
			my $RunPaper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			my $Paper = $RunPaper->Supplied();
			my $paper_id = $Paper->id_string();
			my $stock_index = $indexes{$paper_id};
			if ( ! $stock_index ) {
$openprint::log->error("2No stock index for $paper_id");
			} # end if
			next if $Paper->supplied();

			if ( $$specs{"overridecost-$form-$stock_index-$qty_index"} ne 'Y' ) {
				my $price;
				if ( $Paper->type() eq 'Sheet' ) {
					$price = $Paper->get_price( sheets=>$totals{$paper_id}{"qty_$qty_index"},service=>'Material' );
				} else {
					$price = $Paper->get_price( weight=>$totals{$paper_id}{"qty_$qty_index"},service=>'Material' );
				} # end if
				$$specs{"cost-$form-$stock_index-$qty_index"} = $$price{'100lb Price'};
#$openprint::log->warn("Getting prices for $stock_index $paper_id (".$totals{$paper_id}{"qty_$qty_index"}.'sheets) => $' . $price{'100lb Price'}.'/100lb');
			} # end if
			$$specs{"price-$form-$stock_index-$qty_index"} = Math::Round::nearest( 0.01, $$specs{"cost-$form-$stock_index-$qty_index"} * $$specs{"qty-$form-$stock_index-$qty_index"} / 100 );
			$totals{$paper_id}{'Cost'}[$qty_index] = $$specs{"cost-$form-$stock_index-$qty_index"};
			$$specs{"MPrice$qty_index"} += $$specs{"cost-$form-$stock_index-$qty_index"} * ceil( (1000/$$sig_specs{'txtImposition'.$qty_index}) * $RunPaper->sheet_weight() )/ 100;
		} # end foreach qty_index
	} # end foreach signature

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		my $stock_index = 1;
		$$specs{"txtPrice$qty_index"} = 0;
		foreach my $paper_id ( sort keys %papers ) {
			my $Paper = $papers{$paper_id};
			if ( DEBUG ) {
				$openprint::log->debug($paper_id . ' => totals: ' . $totals{$paper_id}{"qty_$qty_index"} );
				if ( ! $totals{$paper_id}{"qty_$qty_index"} ) {
					foreach my $k ( keys %totals ) {
						$openprint::log->debug("Totals: $k => ".$totals{$k}{"qty_$qty_index"} );
					}
				}
			} # end if
			if ( $Paper->type() eq 'Sheet' ) {
				$$specs{"qty-$stock_index-$qty_index"} = Math::Round::nearest( 0.1, ( $totals{$paper_id}{"qty_$qty_index"} * $Paper->sheet_weight() ) );
				$$specs{"sheets-$stock_index-$qty_index"} = $totals{$paper_id}{"qty_$qty_index"};
			} else {
				$$specs{"qty-$stock_index-$qty_index"} = $totals{$paper_id}{"qty_$qty_index"};
				$$specs{"sheets-$stock_index-$qty_index"} = ceil( $totals{$paper_id}{"qty_$qty_index"} / $Paper->start_sheet_weight() ) if $Paper->start_sheet_weight();
			} # end if
			$$specs{"txtPrice$qty_index"} += $$specs{"qty-$stock_index-$qty_index"} * $totals{$paper_id}{"Cost"}[$qty_index] / 100;
			$stock_index += 1;
		} # end foreach Stock
		$$specs{"MPrice$qty_index"} = sprintf($openprint::config{'UnitPriceFormat'}, $$specs{"MPrice$qty_index"} * (1+$Project->markup()/100) );
		$$specs{"txtPrice$qty_index"} = sprintf($openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} * (1+$Project->markup()/100) );
$openprint::log->debug("Price $qty_index " . $$specs{"txtPrice$qty_index"} ) if DEBUG;
	} # end foreach qty_index

	return $$specs{Status};
} # end sub calc

sub display {
	my ( $self, $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my %totals;
	my $Project = new openprint::Project( $project_index );

	foreach my $signature_service_index ( $Project->signatures() ) {
		my $sig_specs = openprint::service::get_specs_ref( $Project, $signature_service_index );
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
				my $list_id = openprint::pricing::get_pricelist_id();
				$price = openprint::pricing::get_best_price( $$variable{'company_id'}, $totals{$id}{Index}, $list_id, 'openprint::paper_priceset', 1 );
				my $discounted_price = openprint::pricing::get_best_price( $$variable{'company_id'}, $totals{$id}{Index}, $list_id, 'openprint::paper_priceset', $totals{$id}{'hdnGrossSheetCount'.$qty_index} );
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
		foreach my $q_index ( $Project->quantity_indexes() ) {
			next if ! $$sig_specs{'txtImposition'.$q_index};
			my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $q_index )->Supplied();
			next if ! ( $Paper->id() or $$Paper{custom} );
			$Papers{$Paper->id_string()} = $Paper;
        } # end foreach qty_index
    } # end foreach

	my @keys = sort keys %Papers;

	if ( $qty_index ) {
		my @summaries;
		my $stock_id = 1;
		foreach my $key ( @keys ) {
			my $html = '';
			my $Paper = $Papers{$key};
#$openprint::log->warn("Stock QTY $stock_id $qty_index " . $$specs{"qty-$stock_id-$qty_index"} );
			if ( $$specs{"qty-$stock_id-$qty_index"} ) {
				if ( $Paper->type() eq 'Sheet' ) {
					$html .= $$specs{"sheets-$stock_id-$qty_index"}.'sheets ';
				} # end if
				$html .= Number::Format::format_number( Math::Round::nearest(1, $$specs{"qty-$stock_id-$qty_index"} ) ).' lbs';
				my $Price = $Paper->get_price( 'weight'=>$$specs{"qty-$stock_id-$qty_index"},'service'=>'Material' );
				if ( $$Price{'units'} eq 'per square foot' ) {
					$html .= ' ' . Math::Round::nearest( 1, ( $$specs{"qty-$stock_id-$qty_index"} / $Paper->wpsi() ) / 144 ).' sq feet';
				} elsif ( $$Price{'units'} eq 'per square inch' ) {
					$html .= ' ' . Math::Round::nearest( 1, $$specs{"qty-$stock_id-$qty_index"} / $Paper->wpsi() ). ' sq inches';
				} elsif ( $$Price{'units'} eq 'per 100lbs' ) {
				if ( ( $Paper->type() eq 'Roll' ) and ( $$specs{"qty-$stock_id-$qty_index"} > 100 ) ) {
					$html .= ' ' . int( ( ( $$specs{"qty-$stock_id-$qty_index"} / $Paper->wpsi() ) / $Paper->width() ) / 12 ) . ' feet';
				} # end if
				} elsif ( $$Price{'units'} ) {
					$html .= 'unknown units: ' . $$Price{'units'};
				} elsif ( sets::isin( $Project->Type()->name(), [ 'Banners' ] ) ) {
					$html .= ' ' . Math::Round::nearest(1, ( $$specs{"qty-$stock_id-$qty_index"} / $Paper->wpsi() ) / $Paper->width() ).'inches';
				} # end if
			} else {
				$html .= 'none';
			} # end if
			push @summaries, $html;
			$stock_id += 1;
		} # end foreach key
		return \@summaries;
	} # end if
	return [ map { $Papers{$_}->message() ? $_ . '<br/><span class="StockMessage">'. ssi::variable_substitution( \$Papers{$_}->message(), { Project => $Project } ) . '</span>' : $_ } @keys ];
} # end sub summary

sub save {
} # end sub save

sub get_stocks_and_quantities {
    my ( $Project, $service_id, $specs, $qty_index ) = @_;

    $specs = openprint::service::get_specs_ref( $Project, $service_id ) if ! $specs;

    my %Papers;
    foreach my $ss_id ( $Project->signatures() ) {
        my $sig_specs = openprint::service::get_specs_ref( $Project, $ss_id );
        foreach my $q_index ( $Project->quantity_indexes() ) {
            next if ! $$sig_specs{'txtImposition'.$q_index};
            my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $q_index )->Supplied();
            next if ! ( $Paper->id() or $$Paper{custom} );
            $Papers{$Paper->id_string()} = $Paper;
        } # end foreach qty_index
    } # end foreach

    my @keys = sort keys %Papers;

	my %quantities;

	my $stock_id = 1;
	foreach my $key ( @keys ) {
		my $Paper = $Papers{$key};
#$openprint::log->warn("Stock QTY $stock_id $qty_index " . $$specs{"qty-$stock_id-$qty_index"} );
		if ( $$specs{"qty-$stock_id-$qty_index"} ) {
			if ( $Paper->type() eq 'Sheet' ) {
				$quantities{$key} += $$specs{"sheets-$stock_id-$qty_index"};
			} else {
				$quantities{$key} += $$specs{"qty-$stock_id-$qty_index"};
			} # end if
		} # end if
		$stock_id += 1;
	} # end foreach key
	return map { { Stock => $Papers{$_}, quantity => $quantities{$_} } } @keys;

} # end sub get_stocks_and_quantities

1;
__END__
