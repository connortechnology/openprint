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

package openprint::Estimating::Counting;
use strict;

require sql;
require openprint::service;

my @variables = (
        'txtPrice1', 'txtPrice2', 'txtPrice3',
        'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
);

sub variables { return @variables; }

my @no_output = (
    'ProjectIndex','ServiceIndex','ServiceType',
    'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
);

sub no_outputs { return @no_output; } # end sub no_outputs


sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $makeReadyPrice = openprint::service::get_price( $log, $dbh, $variable, 'CountingMakeReady', undef, undef );
	my $minimumCharge = openprint::service::get_price( $log, $dbh, $variable, 'CountingMinimumCharge', undef, undef );

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} =~ s/\D//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity( $qty_index ) if ! $$specs{"txtQuantity$qty_index"};
		next if ! $$specs{"txtQuantity$qty_index"};
		$$specs{'hdnBreakdown'.$qty_index} = '';
		$$specs{'hdnBreakdown'.$qty_index}  .= 'MakeReady: ' . sprintf( '%.2f', $makeReadyPrice ) . "\n";
		$$specs{'hdnBreakdown'.$qty_index}  .= 'MinimumCharge: ' . sprintf( '%.2f', $minimumCharge ) . "\n";

		my %ServicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'Counting', $$specs{"txtQuantity$qty_index"}, undef );
		if ( sets::isin( $ServicePrice{'units'}, ['Per M', 'Per 1000'] ) ) {
			$ServicePrice{'Total'} = $ServicePrice{'Price'} * $$specs{"txtQuantity$qty_index"} / 1000;
		} else {
			$log->error('Unknown units for Counting service price');
		} # end if
		my $price = $makeReadyPrice + $ServicePrice{'Total'};
		if ( $minimumCharge > 0 and $price < $minimumCharge ) {
			$price = $minimumCharge;
		} # end if

		$$specs{"txtUnitPrice$qty_index"} = sprintf( '%.2f', $price / $$specs{"txtQuantity$qty_index"} );
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
	} # end foreach
	return $$specs{'Status'} = 'calculated';
} # end sub calc

sub summary {
} # end sub summary

1;

__END__
