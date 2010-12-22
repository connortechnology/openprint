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

package openprint::Estimating::Turnaround;
use strict;

require openprint::service;

require sql;
require misc;

my @variables = (
		'txtPrice1',
        'txtPrice2',
        'txtPrice3',
		'TurnaroundDays',
);

sub variables {
    return @variables;
}


sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $Project = new openprint::Project( $project_index );
	my $ProjectType = $Project->Type();

	my %Price = openprint::service::get_price_object( $ProjectType->name().'Turnaround', $$specs{'TurnaroundDays'} );
	if ( ! %Price ) {
		%Price = openprint::service::get_price_object( 'Turnaround', $$specs{'TurnaroundDays'} );
	} # end if
	
	foreach my $qty_index ( $Project->quantity_indexes() ) {
		if ( $Price{'units'} eq 'Percent' ) {
			my ( $price ) = misc::sum( sql::execute( $log, $dbh, qq{SELECT strValue FROM tbl_Service_Specifications WHERE lngProjectIndex=? AND lngServiceIndex != ? and strName='txtPrice$qty_index'}, $project_index, $service_index ) );
			$$specs{"txtPrice$qty_index"} = $price * $Price{'Price'}/100;
		} else {
			$$specs{"txtPrice$qty_index"} = $Price{'Price'};
		} # end if
		$$specs{"txtPrice$qty_index"} = sprintf( $openprint::config{'ProjectMoneyFormat'}, $$specs{"txtPrice$qty_index"} );
	} # end foreach
	return 'calculated';
} # end sub calc_prepress
sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;

	if ( $qty_index ) {
		return '';
	} # end if
	return sprintf('%d days.',$$specs{'TurnaroundDays'});
} # end sub summary
sub project_summary {
	my ( $Project, $service_id, $specs ) = @_;
	return sprintf(' in %d days.',$$specs{'TurnaroundDays'});
} # end sub project_summary
1;
__END__
