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

package openprint::Estimating::CopyDot;

use strict;

require sql;
require openprint::print;
require openprint::service;

my @variables = (
        'txtPrice1', 'txtPrice2', 'txtPrice3',
        'txtNegativeQuantity1', 'txtNegativeQuantity3', 'txtNegativeQuantity2',
		'chkOverrideNegativeQuantity',
);

sub variables {
	return @variables;
} # end sub variables

my @no_output = (
	'chkOverrideNegativeQuantity',
	'txtQuantity1', 'txtQuantity2', 'txtQuantity3',
	'ProjectIndex','ServiceIndex','ServiceType',
);

sub no_outputs {
	return @no_output;
}

sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;
	my $status = 'calculated';
	my $Project = new openprint::Project( $project_index );

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		next if ! $$specs{'txtQuantity'.$qty_index};
		if ( $$specs{'chkOverrideNegativeQuantity'} ne 'Y' ) {
			@no_output = sets::exclude( ['txtNegativeQuantity'.$qty_index], \@no_output );
			$$specs{'txtNegativeQuantity'.$qty_index} = 0;
			foreach my $ss_id ( $Project->signatures() ) {
				my $sig_specs = openprint::service::get_specs_ref( $project_index, $ss_id );
				$$specs{'txtNegativeQuantity'.$qty_index} += $$sig_specs{'txtPlateQuantity'.$qty_index};
			} # end foreach
			if ( ! $$specs{'txtNegativeQuantity'.$qty_index} ) {
				$$specs{'alert'} .= "No plates found for quantity $qty_index<br/>";
				$status = 'uncalculated';
			} # end if
		} else {
			@no_output = sets::union( 'txtNegativeQuantity'.$qty_index, @no_output );
		} # end if
		my $service_price = openprint::service::get_price( 'CopyDot', $$specs{'txtNegativeQuantity'.$qty_index}, undef );
		$$specs{'txtUnitPrice'.$qty_index} = sprintf('%.2f', $service_price );
		$$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{'ProjectMoneyFormat'}, $service_price * $$specs{'txtNegativeQuantity'.$qty_index} );
	} # end foreach

	return $status;
} # end sub calc

1;
__END__
