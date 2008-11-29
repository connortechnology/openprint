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
			$papers{$Paper->to_string()} = $Paper;
			#my $string = sprintf( '%s %s %s %s', $Paper->name(), $Paper->finish(), $Paper->colour(), $Paper->weight() );
			if ( $Paper->type() eq 'Roll' ) {
				#$string .= sprintf(' %s&quot; Roll', $Paper->width() );
				my $impressions = $$sig_specs{'hdnImpressionQuantity'.$qty_index};
				if ( sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble'] ) ) {
					$impressions /= 2;
				} elsif ( $$sig_specs{'ddmRunStyle'.$qty_index} eq 'Sheet Work' ) {
					my @side_one_colours = openprint::Estimating::Printing::get_colours( $specs, 'SideOne' );
					my @side_two_colours = openprint::Estimating::Printing::get_colours( $specs, 'SideTwo' );
					if ( @side_one_colours and @side_two_colours ) {
						$impressions /= 2;
					} # end if
				} # end if
				$totals{$Paper->to_string()}[$qty_index] += sprintf('%.0f', $impressions * $Paper->area() * $Paper->wpsi());
			} elsif ( $Paper->type() eq 'Sheet' ) {
				#$string .= sprintf(' %s&quot;x%s&quot;', $Paper->width(), $Paper->height() );
				my $sheets = $$sig_specs{'SheetQuantity'.$qty_index};
				$sheets /= ( $Paper->start_area() /$Paper->area() );
				$sheets = ceil( $sheets );
				#$totals{$Paper->to_string()}[$qty_index] += $sheets;
				$totals{$Paper->to_string()}[$qty_index] += ceil( $sheets * $Paper->start_area() * $Paper->wpsi() );
			} # end if
		} # end foreach qty_index
	} # end foreach signature
	foreach my $qty_index ( 1 .. 3 ) {
		next if ! $Project->quantity( $qty_index );
		foreach my $paper_id ( keys %totals ) {
			my $Paper = $papers{$paper_id};
			if ( ! $Paper->supplied() ) {
				my %price = $Paper->get_price( $totals{$paper_id}[$qty_index] );
			#my %price = sheet_calc( $Paper, $totals{$paper_id}[$qty_index] );
				$price{'Total'} = $price{'100lb Price'} * $totals{$paper_id}[$qty_index] / 100;

$openprint::log->warn("Paper price for " . $totals{$paper_id}[$qty_index] . ' of ' . $Paper->to_string() . ' : ' . $price{'Total'} ) if $debug;
			$$specs{"txtPrice$qty_index"} += $price{'Total'};
			} # endif
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
		foreach my $qty_index ( 1 .. 3 ) {
            next if ! $Project->quantity( $qty_index );
			next if ! $$sig_specs{'txtImposition'.$qty_index};
			my $Paper = openprint::Paper::load_from_signature( $Project, $sig_specs, $qty_index );
			my $string = '';
			$string .= 'Customer Supplied ' if $Paper->supplied();
			$string .= sprintf( '%s %s %s %s', $Paper->name(), $Paper->finish(), $Paper->colour(), $Paper->weight() );
			if ( $Paper->type() eq 'Roll' ) {
				$string .= sprintf(' %s&quot; Roll', $Paper->width() );
				
				my $impressions = $$sig_specs{'hdnImpressionQuantity'.$qty_index};
				if ( sets::isin( $$sig_specs{'ddmRunStyle'.$qty_index}, ['Work & Turn','Work & Tumble'] ) ) {
					$impressions /= 2 
				} elsif ( $$sig_specs{'ddmRunStyle'.$qty_index} eq 'Sheet Work' ) {
					my @side_one_colours = openprint::Estimating::Printing::get_colours( $specs, 'SideOne' );
					my @side_two_colours = openprint::Estimating::Printing::get_colours( $specs, 'SideTwo' );
					if ( @side_one_colours and @side_two_colours ) {
						$impressions /= 2 
					} # end if
				} # end if
				$totals{$string}[$qty_index] += sprintf('%.0f', $impressions * $Paper->area() * $Paper->wpsi());
#$$openprint::log->debug("I: $impressions * $$Paper{width} * $$Paper{height} * " . $Paper->wpsi() . " = " . $totals{$string}[$qty_index] );
					
			} elsif ( $Paper->type() eq 'Sheet' ) {
				$string .= sprintf(' %s&quot;x%s&quot;', $Paper->start_width(), $Paper->start_height() );
               my $sheets = $$sig_specs{'SheetQuantity'.$qty_index};
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

1;
__END__
