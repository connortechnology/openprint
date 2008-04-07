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

package openprint::Estimating::Prepress;
use strict;

require openprint::project;
require openprint::service;

require sql;

my @variables = (
        'txtPrice', 'txtPrice1', 'txtPrice2', 'txtPrice3',
        'txtRunTime1', 'txtRunTime2', 'txtRunTime3',
        'txtQuantity',
);

sub variables {
    return @variables;
}

my @no_outputs = (
	'ProjectIndex','ServiceIndex','ServiceType',
	'txtQuantity',
);
sub no_outputs {
	return @no_outputs;
}


sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';
	my $ServiceType = new openprint::ServiceType( openprint::service::get_type_id( $project_index, $service_index ) );

	if ( $$specs{'txtQuantity'} eq '' ) {	# a zero value is still calculated, just with a zero price.
		$status = 'uncalculated';
	} elsif ( $$specs{'txtQuantity'} < 0.25 and $$specs{'txtQuantity'} > 0 ) {
		$$specs{'txtQuantity'} = 0.25;
	} # end if
	my $price = openprint::service::get_price( $ServiceType->name(), $$specs{'txtQuantity'}, undef );
	$$specs{"txtUnitPrice"} = sprintf( $openprint::config{'UnitPriceFormat'}, $price );

	$price *= $$specs{'txtQuantity'};
	$$specs{"txtPrice"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $price );
	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtUnitPrice$qty_index"} = $$specs{"txtUnitPrice"};
		$$specs{"txtPrice$qty_index"} = $$specs{"txtPrice"};
	} # end foreach
	$$specs{'Status'} = $status;
	return $status;
} # end sub calc

1;
__END__
