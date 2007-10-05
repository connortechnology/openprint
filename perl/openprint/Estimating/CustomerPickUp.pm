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

package openprint::Estimating::CustomerPickUp;
use strict;
use POSIX qw(ceil);

require sql;
require sets;

my %variables = (
	'txtPackageQuantity1' => ['save','output'],
	'txtPackageQuantity2' => ['save','output'],
	'txtPackageQuantity3' => ['save','output'],
	'txtPrice1'=>['save'], 'txtPrice2'=>['save'], 'txtPrice3'=>['save'],
	'txtQuantity1'=>['save','output'], 'txtQuantity2'=>['save','output'], 'txtQuantity3'=>['save','output'],
    'chkOverridePackageQuantity'=>['save'],
    'txtTotalWeight1'=>['save','output'], 'txtTotalWeight2'=>['save','output'], 'txtTotalWeight3'=>['save','output'],
    'txtPackageWeight'=>['save','output'],
);

sub variables {
    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k, if sets::isin( 'save', $variables{$k} );
    } # end foreach;
    return @v;
}

sub no_outputs {
    my @v;
    foreach my $k ( keys %variables ) {
        push @v, $k, if ! sets::isin( 'output', $variables{$k} );
    } # end foreach;
    return @v;
}


sub calc {
	my ( $log, $dbh, $variable, $project_index, $service_index, $specs ) = @_;

	my $status = 'calculated';

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();
	my ( $carton_service_index ) = $services{'PlainCartons'}[0] if $services{'PlainCartons'};
	( $carton_service_index ) = $services{'BulkSkids'}[0] if $services{'BulkSkids'};
	if ( ! $carton_service_index ) {
		$$specs{'alert'} .= 'Project must be in cartons or on skids.<br/>';
		return 'uncalculated';
	} # end if
	if ( 'uncalculated' eq openprint::service::status( $project_index, $carton_service_index ) ) {
		$$specs{'alert'} .= 'Carton service has not been calculated yet.';
		return 'uncalculated';
	} # end if

	my $carton_specs = openprint::service::get_specs_ref( $project_index, $carton_service_index );

	if ( $$specs{'chkOverridePackageWeight'} ne 'Y' ) {
# Load from skids or cartons
		$$specs{"txtPackageWeight"} = $$carton_specs{"txtPackageWeight"};
	} # end if
	foreach my $qty_index ( 1 .. 3 ) {
		next if ! $Project->quantity( $qty_index );
		# Ensure Cardinality of Quantity
		$$specs{'txtQuantity'.$qty_index} =~ s/\D//g;
		$$specs{'txtQuantity'.$qty_index} = $Project->quantity($qty_index) if $$specs{'txtQuantity'.$qty_index} > $Project->quantity($qty_index);
			
		$$specs{'txtPackageQuantity'.$qty_index} = ceil($$specs{'txtQuantity'.$qty_index}/$$carton_specs{txtItemsPerPackage});
		$$specs{"txtTotalWeight$qty_index"} = sprintf('%.2f', (int( $$specs{'txtQuantity'.$qty_index}/$$carton_specs{'txtItemsPerPackage'} ) * $$specs{'txtPackageWeight'}) + (($$specs{'txtQuantity'.$qty_index} % $$carton_specs{'txtItemsPerPackage'} ) * $$carton_specs{'txtFinishedWeight'}) );
	} # end foreach

	return $status;
} # end sub calc

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	if ( $qty_index ) {
		return sprintf( qq{%d items in %d package%s\nWeighing %.2flbs}, @$specs{'txtQuantity'.$qty_index,'txtPackageQuantity'.$qty_index},( $$specs{'txtPackageQuantity'.$qty_index}==1?'' : 's'), $$specs{'txtTotalWeight'.$qty_index} );
	} # end if
} # end sub summary
1;
__END__
