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

package openprint::Estimating::Shipping;
use strict;

require openprint::project;
require openprint::obj_customer;

require sql;
require sets;

my %variables = (
	'txtPrice1'=>['save'], 'txtPrice2'=>['save'], 'txtPrice3'=>['save'],
	'txtQuantity1'=>['save'], 'txtQuantity2'=>['save'], 'txtQuantity3'=>['save'],
	'txtPackageQuantity1'=>['save','output'], 'txtPackageQuantity2'=>['save','output'], 'txtPackageQuantity3'=>['save','output'],
    'chkOverridePackageQuantity' => ['save'],
    'txtTotalWeight1'=>['save','output'], 'txtTotalWeight2'=>['save','output'], 'txtTotalWeight3'=>['save','output'],
    'txtPackageWeight'=>['save','output'],
    'Address1'=>['save'],'Address2'=>['save'],'City'=>['save'],'StateProvince'=>['save'],'Country'=>['save'],'PostalCode'=>['save'],'Phone'=>['save'],'Fax'=>['save'],

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

	my $Project = new openprint::Project( $project_index );
	my %services = $Project->get_services();

	my $status = 'calculated';
	my ( $carton_service_index ) = $services{'PlainCartons'}[0] if $services{'PlainCartons'}[0];
	if ( ! $carton_service_index ) {
		$$specs{'alert'} = 'Shipping requires that the project be packed in cartons.';
		$$specs{'NeedPlainCartons'} = 1;
		return 'uncalculated';
	} else {
		$$specs{'NeedPlainCartons'} = 0;
	} # end if
	my $carton_status = openprint::service::get_status( $log, $dbh, $carton_service_index, $project_index );
	$log->debug("Carton Status: $carton_status");
	if ( sets::isin( $carton_status,['', 'uncalculated'] ) ) {
		openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $carton_service_index, 'Skids' );
	} # end if
	my $carton_specs = openprint::service::get_specs_ref( $project_index, $carton_service_index );

	if ( $$specs{'chkOverridePackageWeight'} ne 'Y' ) {
# Load from skids or cartons
		$$specs{"txtPackageWeight"} = $$carton_specs{"txtPackageWeight"};
	} # end if
	if ( ! $$carton_specs{'txtItemsPerPackage'} ) {
		$$specs{'alert'} = 'Unable to determine how many items per carton.';
		return 'uncalculated';
	} # end if

	foreach my $qty_index ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		next if ! $$specs{"txtQuantity$qty_index"};
		if ( $$specs{'chkOverridePackageQuantity'} ne 'Y' ) {
			$$specs{'txtPackageQuantity'.$qty_index} = $$carton_specs{'txtPackageQuantity'.$qty_index};
		} # end if
		$$specs{"txtTotalWeight$qty_index"} = sprintf('%.2f', (int( $$specs{'txtQuantity'.$qty_index}/$$carton_specs{'txtItemsPerPackage'} ) * $$specs{'txtPackageWeight'}) + (($$specs{'txtQuantity'.$qty_index} % $$carton_specs{'txtItemsPerPackage'} ) * $$carton_specs{'txtFinishedWeight'}) );
	} # end foreach
	return $status;
} # end sub calc

sub display {
	my ( $r, $log, $dbh, $variable, $project_index, $service_index ) = @_;

    if ( $openprint::session{'company_id'} and ( ! (
        $$variable{'City'} and $$variable{'PostalCode'} and $$variable{'StateProvince'} and $$variable{'Country'} ) ) ) {
        my %shipping_fields = (
                'Address1'       =>  'Address1',
                'Address2'       =>  'Address2',
                'City'           =>  'City',
                'StateProvince'  =>  'StateProvince',
                'Country'        =>  'Country',
                'PostalCode'     =>  'PostalCode',
                );

        my $company = new openprint::obj_customer( $log, $dbh, $openprint::session{'company_id'} );
        @$variable{ keys %shipping_fields } = $company->load_shipping( @shipping_fields{ keys %shipping_fields } );
    } # end if

} # end sub display

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	if ( $qty_index ) {
		if ( $$specs{'txtPackageQuantity'.$qty_index} ) {
		return sprintf( qq{%d items in %d package%s\nWeighing %.2flbs}, @$specs{'txtQuantity'.$qty_index,'txtPackageQuantity'.$qty_index},( $$specs{'txtPackageQuantity'.$qty_index}==1?'' : 's'), $$specs{'txtTotalWeight'.$qty_index} );
		} else {
		return sprintf( q{%d items}, $$specs{'txtQuantity'.$qty_index} );
		} # end if
	} else {
		if ( $$specs{'Address1'} or $$specs{'City'} or $$specs{'StateProvince'} or $$specs{'Country'} ) {
		return join("\n", 
			join(',', $$specs{'CompanyName'} ) ,
			join(',', $$specs{'Address1'} , $$specs{'Address2'},
			@$specs{'City','StateProvince','Country'},
			@$specs{'PostalCode'} ),
			);
		} else {
			return 'unspecified address';
		} # end if
	} # end if
} # end sub summary

1;
__END__
