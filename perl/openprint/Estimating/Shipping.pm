# Copyright (C) 2007 Isaac Connor <isaac@connortechnology.com>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA	02110-1301, USA

package openprint::Estimating::Shipping;
use strict;
use POSIX qw{ ceil };

require openprint::project;
require openprint::obj_customer;

require sql;
require sets;

my %variables = (
	'txtPrice1'=>['save','output'], 'txtPrice2'=>['save','output'], 'txtPrice3'=>['save','output'],'txtPriceUsed'=>['save'],
	'txtQuantity1'=>['save','output'], 'txtQuantity2'=>['save','output'], 'txtQuantity3'=>['save','output'],'txtQuantityUsed'=>['save'],
	'txtPackageQuantity1'=>['save','output'], 'txtPackageQuantity2'=>['save','output'], 'txtPackageQuantity3'=>['save','output'],'txtPackageQuantityUsed'=>['save'],
    'chkOverridePackageQuantity' => ['save'],
	'txtTotalWeight1'=>['save','output'], 'txtTotalWeight2'=>['save','output'], 'txtTotalWeight3'=>['save','output'],'txtTotalWeightUsed'=>['save'],
    'txtPackageWeight1'=>['save','output'], 'txtPackageWeight2'=>['save','output'], 'txtPackageWeight3'=>['save','output'],'txtPackageWeightUsed'=>['save'],

	'FromCompanyName'=>['save'],'FromAddress1'=>['save'],'FromAddress2'=>['save'],'FromCity'=>['save'],'FromStateProvince'=>['save'],'FromCountry'=>['save'],'FromPostalCode'=>['save'],'FromPhone'=>['save'],'FromFax'=>['save'],'FromEmail'=>['save'],
	'ToCompanyName'=>['save'],'ToAddress1'=>['save'],'ToAddress2'=>['save'],'ToCity'=>['save'],'ToStateProvince'=>['save'],'ToCountry'=>['save'],'ToPostalCode'=>['save'],'ToPhone'=>['save'],'ToFax'=>['save'],'ToEmail'=>['save'],
	'FromFirstName'=>['save'],'FromLastName'=>['save'],
	'ToFirstName'=>['save'],'ToLastName'=>['save'],
	'alert'=>['save','output'],
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
	my $services = $Project->services();
	$$specs{'alert'} = '';
	my $status = 'calculated';
	my ( $carton_service_index ) = $$services{'PlainCartons'}[0] if $$services{'PlainCartons'}[0];
	if ( ! $carton_service_index ) {
		$$specs{'alert'} = 'Shipping requires that the project be packed in cartons.';
		$$specs{'NeedPlainCartons'} = 1;
		return 'uncalculated';
	} else {
		$$specs{'NeedPlainCartons'} = 0;
	} # end if
	my $carton_status = openprint::service::status( $project_index, $carton_service_index );
	if ( sets::isin( $carton_status,['', 'uncalculated'] ) ) {
		openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $carton_service_index, 'Skids' );
	} # end if
	my $carton_specs = openprint::service::get_specs_ref( $Project, $carton_service_index );

	if ( ! $$specs{'ToCity'} ) {
		$$specs{'alert'} .= 'Please enter To city<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( !$$specs{'ToPostalCode'} ) {
		$$specs{'alert'} .= 'Please enter To Postal Code<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( !$$specs{'ToStateProvince'} ) {
		$$specs{'alert'} .= 'Please enter To State/Province<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	if ( ! $$specs{'ToCountry'} ) {
		$$specs{'alert'} .= 'Please enter To Country<br/>';
		return $$specs{'Status'} = 'uncalculated';
	} # end if
	my @shipping_services;
	foreach my $ServiceType ( openprint::ServiceType::find('category'=>'Shipping') ) {
		next if ! $$services{$ServiceType->name()};
		foreach ( @{$$services{$ServiceType->name()}} ) {
			push @shipping_services, $_ if $_ != $service_index;
		} # end foreach
	} # end foreach ServiceType

	foreach my $qty_index ( $Project->quantity_indexes() ) {
		$$specs{"txtPrice$qty_index"} =~ s/[^\-\.\d]//g;
		$$specs{"txtQuantity$qty_index"} =~ s/\D//g;
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		if ( ! $$specs{"txtQuantity$qty_index"} ) {
			$log->debug("No qty");
		} # end if

		if ( $$specs{'chkOverridePackageWeight'.$qty_index} ne 'Y' ) {
	# Load from skids or cartons
			$$specs{"txtPackageWeight".$qty_index} = $$carton_specs{"txtPackageWeight".$qty_index};
		} # end if
		if ( ! $$carton_specs{'txtItemsPerPackage'.$qty_index} ) {
			$$specs{'alert'} = 'Unable to determine how many items per carton for qty '. $qty_index;
		} # end if

        my $other_shipped_quantity = 0;
        foreach my $sid ( @shipping_services ) {
            my $service_specs = openprint::service::get_specs_ref( $Project, $sid );
            $other_shipped_quantity += $$service_specs{'txtQuantity'.$qty_index};
        } # end foreach sid
$openprint::log->debug("Other Shipped Quantity: $other_shipped_quantity");

        if ( $$specs{'txtQuantity'.$qty_index} == $Project->quantity($qty_index) ) {
            $$specs{'txtQuantity'.$qty_index} = $Project->quantity($qty_index) - $other_shipped_quantity;
        } # end if

		if ( ! $$specs{'txtQuantity'.$qty_index} ) {
            $$specs{'alert'} .= 'Please enter the amount in this shipment.<br/>';
            $status = 'uncalculated';
		} # end if

        if ( $other_shipped_quantity + $$specs{'txtQuantity'.$qty_index} > $Project->quantity( $qty_index ) ) {
            $$specs{'alert'} .= 'There are more items being shipped or picked up than are being produced. Please edit the quantities being shipped or picked up. Recommended amount: ' . ($Project->quantity($qty_index) - $other_shipped_quantity) . '<br/>';
            $status = 'uncalculated';
        } # end if

		if ( $$specs{'chkOverridePackageQuantity'} ne 'Y' ) {
			$$specs{'txtPackageQuantity'.$qty_index} = ceil( $$specs{'txtQuantity'.$qty_index}/$$carton_specs{'txtItemsPerPackage'.$qty_index} );
		} # end if
		$$specs{"txtTotalWeight$qty_index"} = sprintf('%.2f', (int( $$specs{'txtQuantity'.$qty_index}/$$carton_specs{'txtItemsPerPackage'.$qty_index} ) * $$specs{'txtPackageWeight'.$qty_index}) + (($$specs{'txtQuantity'.$qty_index} % $$carton_specs{'txtItemsPerPackage'.$qty_index} ) * $$carton_specs{'txtFinishedWeight'}) );

		$$specs{"txtPrice$qty_index"} = sprintf('%.2f', $$specs{"txtPrice$qty_index"});
	} # end foreach
	return $$specs{'Status'} = $status;
} # end sub calc

sub display {
	my ( $r, $log, $dbh, $variable, $project_index, $service_index ) = @_;

	if ( ! ( $$variable{'FromCity'} and $$variable{'FromPostalCode'} and $$variable{'FromStateProvince'} and $$variable{'FromCountry'} ) ) {
		my %shipping_fields = (
				'FromCompanyName'	=>	'CompanyName',
				'FromAddress1'		=>	'Address1',
				'FromAddress2'		=>	'Address2',
				'FromCity'			=>	'City',
				'FromStateProvince'	=>	'StateProvince',
				'FromCountry'		=>	'Country',
				'FromPostalCode'	=>	'PostalCode',
				'FromPhone'			=>	'Phone',
				'FromExtension'		=>	'Extension',
				'FromFax'			=>	'Fax',
				'FromEmail'			=>	'Email',
				);

		
		my $company = new openprint::obj_customer( $log, $dbh, $openprint::config{'Owner'} );
		my $address = $company->get_shipping_address();
		foreach my $k ( keys %shipping_fields ) {
			$$variable{$k} = $address->get( $shipping_fields{$k} ) if ! $$variable{$k};
		} # end foreach
	} # end if

	if ( $openprint::session{'company_id'} and ( ! (
		$$variable{'ToCity'} and $$variable{'ToPostalCode'} and $$variable{'ToStateProvince'} and $$variable{'ToCountry'} ) ) ) {
		my %shipping_fields = (
				'ToCompanyName'		=>	'CompanyName',
				'ToAddress1'		=>	'Address1',
				'ToAddress2'		=>	'Address2',
				'ToCity'			=>	'City',
				'ToStateProvince'	=>	'StateProvince',
				'ToCountry'			=>	'Country',
				'ToPostalCode'		=>	'PostalCode',
				'ToPhone'			=>	'Phone',
				'ToExtension'		=>	'Extension',
				'ToFax'				=>	'Fax',
				'ToEmail'			=>	'Email',
				);

		my $company = new openprint::obj_customer( $log, $dbh, $openprint::session{'company_id'} );
		my $address = $company->get_shipping_address();
		foreach my $k ( keys %shipping_fields ) {
			$$variable{$k} = $address->get( $shipping_fields{$k} ) if ! $$variable{$k};
		} # end foreach
	} # end if

} # end sub display

sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	my $services = $Project->services();

	if ( $qty_index eq 'Used' ) {
		my $packages = $$specs{'txtPackageQuantityUsed'} ? $$specs{'txtPackageQuantityUsed'} : $$specs{'txtPackageQuantity'.$Project->ordered_quantity_index()};
		if ( $$services{'PlainCartons'} ) {
			return sprintf( qq{%d items in %d carton%s\nWeighing %.2flbs}, 
				( $$specs{'txtQuantity'.$qty_index} ? $$specs{'txtQuantityUsed'} : $$specs{'txtQuantity'.$Project->ordered_quantity_index()} ),
				$packages, ( $packages==1?'' : 's'), 
				( $$specs{'txtTotalWeightUsed'} ? $$specs{'txtTotalWeightUsed'} : $$specs{'txtTotalWeight'.$Project->ordered_quantity_index()} ),
				);
		} else {
			return sprintf( qq{%d items in %d package%s\nWeighing %.2flbs}, 
				( $$specs{'txtQuantity'.$qty_index} ? $$specs{'txtQuantityUsed'} : $$specs{'txtQuantity'.$Project->ordered_quantity_index()} ),
				$packages, ( $packages==1?'' : 's'), 
				( $$specs{'txtTotalWeightUsed'} ? $$specs{'txtTotalWeightUsed'} : $$specs{'txtTotalWeight'.$Project->ordered_quantity_index()} ),
				);
		} # end if
	}elsif ( $qty_index ) {
		if ( $$specs{'txtPackageQuantity'.$qty_index} ) {
			if ( $$services{'PlainCartons'} ) {
				return sprintf( qq{%d items in %d carton%s\nweighing %.2flbs}, @$specs{'txtQuantity'.$qty_index,'txtPackageQuantity'.$qty_index},( $$specs{'txtPackageQuantity'.$qty_index}==1?'' : 's'), $$specs{'txtTotalWeight'.$qty_index} );
			} else {
				return sprintf( qq{%d items in %d package%s\nweighing %.2flbs}, @$specs{'txtQuantity'.$qty_index,'txtPackageQuantity'.$qty_index},( $$specs{'txtPackageQuantity'.$qty_index}==1?'' : 's'), $$specs{'txtTotalWeight'.$qty_index} );
			} # end if
		} else {
			return sprintf( q{%d items}, $$specs{'txtQuantity'.$qty_index} );
		} # end if
	} else {
		my $html = '';

		if ( $$specs{'FromAddress1'} or $$specs{'FromCity'} or $$specs{'FromStateProvince'} or $$specs{'FromCountry'} ) {
			$html .= 'From: ' . join("\n", 
					join(', ', $$specs{'FromCompanyName'} ) ,
					join(', ', $$specs{'FromAddress1'} , $$specs{'FromAddress2'},
						@$specs{'FromCity','FromStateProvince','FromCountry'},
						@$specs{'FromPostalCode'} ),
					) . '<br/>';
		} # end if
		if ( $$specs{'ToAddress1'} or $$specs{'ToCity'} or $$specs{'ToStateProvince'} or $$specs{'ToCountry'} ) {
			$html .= 'To: ' . join("\n", 
					join(', ', $$specs{'ToCompanyName'} ) ,
					join(', ', $$specs{'ToAddress1'} , $$specs{'ToAddress2'},
						@$specs{'ToCity','ToStateProvince','ToCountry'},
						@$specs{'ToPostalCode'} ),
					);
		} # end if
		if ( ! $html ) {
			return 'unspecified address';
		} # end if
		return $html;
	} # end if
} # end sub summary

1;
__END__
