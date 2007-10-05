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

package openprint::Estimating::CustomService;

use strict;

require sql;
require openprint::print;
require openprint::service;

my @variables = (
		'txtPrice1', 'txtPrice2', 'txtPrice3',
		'Price', 'Units',
);

sub variables {
	return @variables;
} # end sub variables

my @no_output = (
	'Hours1', 'Hours2', 'Hours3','Units',
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
		next if ! $Project->quantity($qty_index);

		my $price;
		if ( $$specs{'Units'} eq 'Per Item' ) {
			$price = $$specs{'Price'.$qty_index} * $Project->quantity($qty_index);
		} elsif ( $$specs{'Units'} eq 'Per M' ) {
			$price = $$specs{'Price'.$qty_index} * $Project->quantity($qty_index)/1000;
		} else { # Flat
			next;
		} # end if
		$$specs{'txtPrice'.$qty_index} = sprintf($openprint::config{'ProjectMoneyFormat'}, $price );
	} # end foreach

	return $status;
} # end sub calc


sub display {
	my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;

} # end sub display

1;
__END__
