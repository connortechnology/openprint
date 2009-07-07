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

package openprint::Estimating::Scanning;
use strict;

require openprint::service;

my @variables = (
        'txtPrice', 'txtPrice1', 'txtPrice2', 'txtPrice3',
        'txtRunTime1', 'txtRunTime2', 'txtRunTime3',
		'txtScanWidth', 'txtScanHeight',
		'txtScanWidthFinal', 'txtScanHeightFinal',
		'txtQuantity',
		'rdbScanner',
		'txtPercent',
		'ddmOriginal',
		'ddmLineScreen',
		'txtLineScreenOther',
		'rdbRandomProof',
);

sub variables {
    return @variables;
}


sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	if ( ! $$specs{'txtScanWidthFinal'} or ! $$specs{'txtScanHeightFinal'} or ! $$specs{'txtQuantity'} or ! $$specs{'rdbScanner'} ) {
		return 'uncalculated';
	} # end if

	my $size = $$specs{'txtScanWidthFinal'} * $$specs{'txtScanHeightFinal'};
	my $makeReady = openprint::service::get_price( $log, $dbh, $variable, $$specs{'rdbScanner'}.'ScanningMakeReady', $$specs{'txtQuantity'}, undef );
	my $runPrice = openprint::service::get_price( $log, $dbh, $variable, 'Scanning', $$specs{'txtQuantity'}, undef );
	my $price = int( $makeReady + $runPrice * $size );

	$$specs{"txtUnitPrice"} = sprintf( '%.2f', $price );
	$price *= $$specs{'txtQuantity'};

	$$specs{"txtPrice"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtUnitPrice$qty_index"} = $$specs{"txtUnitPrice"};
		$$specs{"txtPrice$qty_index"} = $$specs{"txtPrice"};
	} # end foreach
	return $status;
} # end sub calc

sub display {
    my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

	my $specs = openprint::service::get_specs_ref( $project_index, $service_index );
	foreach my $k ( keys %$specs ) {
		$$variable{$k} = $$specs{$k};
	} # end foreach

} # end sub display

sub summary {
}
    

1;
__END__
