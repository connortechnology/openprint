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

package openprint::Estimating::UPS;
use strict;


require XML::LibXML;
require ups;
require sql;
require openprint::service;
require openprint::Project;

my $debug = 1;

my %variables = (
	'txtQuantity1'=>['save','output'], 'txtQuantity2'=>['save','output'], 'txtQuantity3'=>['save','output'],
	'txtPrice1'=>['save','output'], 'txtPrice2'=>['save','output'], 'txtPrice3'=>['save','output'],
	'txtPackageQuantity1'=>['save','output'], 'txtPackageQuantity2'=>['save','output'], 'txtPackageQuantity3'=>['save','output'],
	'chkOverridePackageQuantity'=>['save'],
	'txtTotalWeight1'=>['save','output'], 'txtTotalWeight2'=>['save','output'], 'txtTotalWeight3'=>['save','output'],
	'txtPackageWeight'=>['save','output'],
	'ddmPickupType'=>['save','output'],'ddmServiceType'=>['save','output'],
	'alert'=>['save','output'],'Status'=>['output'],
	'FromCompany'=>['save'],'FromAddress1'=>['save'],'FromAddress2'=>['save'],'FromCity'=>['save'],'FromStateProvince'=>['save'],'FromCountry'=>['save'],'FromPostalCode'=>['save'],'FromPhone'=>['save'],'FromFax'=>['save'],'FromEmail'=>['save'],
	'ToCompany'=>['save'],'ToAddress1'=>['save'],'ToAddress2'=>['save'],'ToCity'=>['save'],'ToStateProvince'=>['save'],'ToCountry'=>['save'],'ToPostalCode'=>['save'],'ToPhone'=>['save'],'ToFax'=>['save'],'ToEmail'=>['save'],
	'ServiceTypeDiv'=>['output'],'PickupTypeDiv'=>['output'],
	'hdnBreakdown1'=>['output'], 'hdnBreakdown2'=>['output'], 'hdnBreakdown3'=>['output'],
	'NeedPlainCartons'=>['output'],
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

$log->debug("UPS!!!!!!!!!!");
	# Currently there is no equipmnet for collating
	$$specs{'alert'} = '';

	@$specs{'txtPrice1','txtPrice2','txtPrice3'} = ('','','');

	my $Project = new openprint::Project( $project_index );
	my $services = $Project->services();

	if ( ! $$services{'PlainCartons'} ) {
		$$specs{'alert'} = 'UPS Shipping requires that the project be packed in cartons.';
		$$specs{'NeedPlainCartons'} = 1;
		return $$specs{'Status'} = 'uncalculated';
	} else {
		$$specs{'NeedPlainCartons'} = 0;
	} # end if
	my $carton_status = openprint::service::status( $project_index, $$services{'PlainCartons'}[0] );
	my $carton_specs;
$log->debug("Carton Status: $carton_status");
	if ( sets::isin( $carton_status ,'', 'uncalculated' ) ) {
		$carton_specs = openprint::service::internal_calc( $log, $dbh, $variable, $project_index, $$services{'PlainCartons'}[0], 'Skids' );
	} else {
		$carton_specs = openprint::service::get_specs_ref( $Project, $$services{'PlainCartons'}[0] );
	} # end if

	if ( $$specs{'chkOverridePackageWeight'} ne 'Y' ) {
		# Load from skids or cartons
		$$specs{"txtPackageWeight"} = $$carton_specs{"txtPackageWeight"};
	} # end if

	my %packages;
	my $qty_index;
	foreach my $qty_i ( 1 .. 3 ) {
		$$specs{"txtQuantity$qty_index"} = $Project->quantity($qty_index) if ! $$specs{"txtQuantity$qty_index"};
		next if ! $$specs{'txtQuantity'.$qty_i};
		$$specs{'hdnBreakdown'.$qty_index} = '';
		if ( $$specs{"chkOverridePackageQuantity"} ne 'Y' ) {
			#@outputs = sets::union( @outputs, 'chkOverridePackageQuantity' );	
			$$specs{"txtPackageQuantity$qty_i"} = $$carton_specs{"txtPackageQuantity$qty_i"};
			my $full_cartons = int ( $$specs{'txtQuantity'.$qty_i} / $$carton_specs{'txtItemsPerPackage'} );
			my $remaining = $$specs{'txtQuantity'.$qty_i} % $$carton_specs{'txtItemsPerPackage'};
			$$specs{"txtTotalWeight$qty_i"} = $full_cartons * $$specs{"txtPackageWeight"} + $remaining * $$carton_specs{'txtFinishedWeight'};;
		} else {
			#@outputs = sets::exclude( [ 'chkOverridePackageQuantity' ], \@outputs );
			$$specs{"txtTotalWeight$qty_i"} = $$specs{"txtPackageWeight"} * $$specs{"txtPackageQuantity$qty_i"};
		} # end if
		$qty_index = $qty_i if $$specs{"txtPackageQuantity$qty_i"} and ! $qty_index;
	} # end foreach
$openprint::log->debug("PostalCode: $$specs{'ToPostalCode'}");
	$$specs{'ToPostalCode'} =~ s/[^0-9A-Za-z]//g;
	if ( ! $$specs{'ToPostalCode'} ) {
		$$specs{'alert'} = 'Please enter your postal code.';
		return $$specs{'Status'} = 'uncalculated';
	} elsif ( length $$specs{'ToPostalCode'} < 4 ) {
		$$specs{'alert'} = 'Invalid Postal/ZIP Code.';
		return $$specs{'Status'} = 'uncalculated';
	} # end if

	my %ups;
	my $access_code = $openprint::config{'UPSAccessCode'};
	my $user_id = $openprint::config{'UPSUserID'};
	my $password = $openprint::config{'UPSPassword'};
	my $accessRequest = ups::createAccessRequest( $access_code, $user_id, $password );

	my %shipping_fields = (
			'ShipperCity'           =>  'City',
			'ShipperStateProvince'  =>  'StateProvince',
			'ShipperCountry'        =>  'Country',
			'ShipperPostalCode'     =>  'PostalCode',
			);
	my ( $supplier_id ) = sql::execute( $log, $dbh, q{SELECT Index FROM Company WHERE ysnSupplier='Y' ORDER BY Index LIMIT 1} );
	my $supplier = new openprint::obj_customer( $log, $dbh, $supplier_id );
	@ups{ keys %shipping_fields } = $supplier->load_shipping( @shipping_fields{ keys %shipping_fields } );
	@ups{'ShipToPostalCode', 'ShipToCity', 'ShipToStateProvince', 'ShipToCountry','PickupType','ServiceType'} = 
		@$specs{'ToPostalCode','ToCity','ToStateProvince','ToCountry','ddmPickupType','ddmServiceType'};

	# Try to auto-fill as many of the ShipTo fields as we can
	if ( ! ( $$specs{'ToPostalCode'} and $$specs{'ToCity'} and $$specs{'ToStateProvince'} and $$specs{'ToCountry'} ) ) {

		# If we are logged in, try to load from shipping, then from basic data
		if ( $openprint::session{'company_id'} ) {
			my $Company = new openprint::obj_customer( $log, $dbh, $openprint::session{'company_id'} );
			my ( $city, $state, $country, $postalcode ) = $Company->load_shipping( 'City','StateProvince','Country','PostalCode' );
			$ups{'ShipToCity'} = $city if ! $ups{'ShipToCity'};
			$ups{'ShipToStateProvince'} = $state if ! $ups{'ShipToStateProvince'};
			$ups{'ShipToCountry'} = $country if ! $ups{'ShipToCountry'};
			$ups{'ShipToPostalCode'} = $postalcode if ! $ups{'ShipToPostalCode'};
		} # end if

		$ups{'ShipToCountry'} = $openprint::session{'Country'} if ! $ups{'ShipToCountry'};
	} # end if

	# Go Shopping
	foreach my $package_index ( 1 .. $$specs{"txtPackageQuantity$qty_index"} ) {
		my %package = ('Length' => '','Width' => '','Height' => '', 'Weight' => $$specs{'txtPackageWeight'} );
		push @{$ups{'Packages'}}, \%package;
	} # end foreach
	my $rssRequest = ups::createShoppingRequest(%ups);
	my $response = ups::sendRequest( $log, 'https://www.ups.com/ups.app/xml/Rate', $accessRequest.$rssRequest );
	if ( $response eq '' ) {
		$$specs{'alert'} = 'Could not connect to ups.com.  We were unable to obtain a shipping estimate. Please select an alternate shipping method, or wait five minutes and try again.';
		return 'uncalculated';
	} # end if
	my $parser = XML::LibXML->new();
	my $doc = $parser->parse_string($response);
	$log->error( "Error parsing: " . $@ ) if $@;
	my %upsResponse;
	ups::extract_RSS( $log, \%upsResponse, $doc );
	if ( $upsResponse{'UPSErrorDescription'} ) {
		$$specs{'alert'} = "Unable to retrieve available service types.  UPS returned the following error:\n$upsResponse{'UPSErrorDescription'}";
		return 'uncalculated';
	} # end if

	my %bestService;
	while ( my ( $service, $price ) = splice @{$upsResponse{'RatedShipments'}}, 0, 2 ) {
		$$specs{'hdnBreakdown'.$qty_index} .= ups::get_service_name($service).": $price\n";
		if ( $$specs{'ddmServiceType'} ) {
			if ( $$specs{'ddmServiceType'} == $service ) {
				$bestService{'Price'} = $price;
				$bestService{'Service'} = $service;
			} # end if
		} else {
			if ( ( ! $bestService{'Price'} ) or ( $price < $bestService{'Price'} ) ) {
				$bestService{'Price'} = $price;
				$bestService{'Service'} = $service;
			} # end if
		} # end if
		$$services{$service} = $price;
	} # end while
	if ( ! $$specs{'ddmServiceType'} ) {
		$log->debug("Choosing  $$specs{'ddmServiceType'} as the ServiceType") if $debug;
		$$specs{'ddmServiceType'} = $bestService{'Service'};
	} # end if
	if ( ! $$specs{'ddmPickupType'} ) {
		$$specs{'ddmPickupType'} = ups::get_pickup_type('One Time Pickup');
	} # end if
	@ups{'PickupType','ServiceType'} = @$specs{'ddmPickupType','ddmServiceType'};

	$$specs{'ServiceTypeDiv'} = qq{<select name="ddmServiceType" onchange="calc(this.form.name);"><option value=""> Select </option>};
	foreach my $service ( keys %$services ) {
		$$specs{'ServiceTypeDiv'} .= qq{<option value="$service"} . ( $$specs{'ddmServiceType'} == $service ? ' selected' : '' ) .'>'.ups::get_service_name( $service ) . '</option>';
	} # end foreach
	$$specs{'ServiceTypeDiv'} .= '</select>';

	$$specs{'PickupTypeDiv'} = qq{<select name="ddmPickupType" onchange="calc(this.form.name);"><option value=""> Select </option>};
	foreach my $pickup ( ups::get_pickup_types() ) {
		$$specs{'PickupTypeDiv'} .= sprintf('<option value="%s"%s>%s</option>',ups::get_pickup_type( $pickup ), $$specs{'ddmPickupType'} == ups::get_pickup_type($pickup) ? ' selected' : '', $pickup );
	} # end while
	$$specs{'PickupTypeDiv'} .= '</select>';

	foreach my $qty_index ( 1 .. 3 ) {
		next if ! $$specs{"txtQuantity$qty_index"};
		next if ! $$specs{"txtPackageQuantity$qty_index"};
		my %bestPrice;

		if ( $$specs{'ddmPickupType'} and $$specs{'ddmServiceType'} ) {
			@{$ups{'Packages'}} = ();

			if ( $$specs{"chkOverridePackageQuantity"} ne 'Y' ) {
				#@outputs = sets::union( @outputs, 'chkOverridePackageQuantity' );	
				$$specs{"txtPackageQuantity$qty_index"} = $$carton_specs{"txtPackageQuantity$qty_index"};
				foreach ( 1 .. int ( $$specs{'txtQuantity'.$qty_index} / $$carton_specs{'txtItemsPerPackage'} ) ) {
					my %package = ('Length' => '','Width' => '','Height' => '', 'Weight' => $$specs{'txtPackageWeight'} );
					push @{$ups{'Packages'}}, \%package;
				} # end foreach

				if ( my $remaining = $$specs{'txtQuantity'.$qty_index} % $$carton_specs{'txtItemsPerPackage'} ) {
					my %package = ('Length' => '','Width' => '','Height' => '', 'Weight' => $remaining * $$carton_specs{'txtFinishedWeight'} );
					push @{$ups{'Packages'}}, \%package;
				} # end if
			} else {
				foreach my $package_index ( 1 .. $$specs{"txtPackageQuantity$qty_index"} ) {
					my %package = ('Length' => '','Width' => '','Height' => '', 'Weight' => $$specs{'txtPackageWeight'} );
					push @{$ups{'Packages'}}, \%package;
				} # end foreach
			} # end if


			my $rssRequest = ups::createRatingServiceSelectionRequest(%ups);
			my $response = ups::sendRequest( $log, 'https://www.ups.com/ups.app/xml/Rate', $accessRequest.$rssRequest );
			if ( $response eq '' ) {
				$$specs{'alert'} = 'Could not connect to ups.com.  We were unable to obtain a shipping estimate. Please select an alternate shipping method, or wait five minutes and try again.';
				return 'uncalculated';
			} # end if
			my $parser = XML::LibXML->new();
			my $doc = $parser->parse_string($response);
			$log->debug($doc->toString());
			my %upsResponse;
			ups::extract_RSS( $log, \%upsResponse, $doc );
			if ( $upsResponse{'UPSErrorDescription'} ) {
				$$specs{'alert'} = "Unable to retrieve a price.  UPS returned the following error:\n$upsResponse{'UPSErrorDescription'}";
				return 'uncalculated';
			} # end if

foreach ( @{$upsResponse{'RatedShipments'}} ) {
	$log->debug("RS: $_");
}

			$_ = $upsResponse{'RatedShipments'}[1];
			$_ =~ /([\d\.]*)(\w*)/;
			my $cost = $1;
			my $currency = $2;
			$log->debug("Currency returned: $currency") if $debug;
			$currency = 'CDN' if $currency eq 'CAD';
			my @currencies = openprint::Currency::find( 'short' => $currency );
			my $UPS_Currency = shift @currencies;
			my $Project = new openprint::Project( $project_index );
			my $MY_Currency = $Project->Currency();
			$log->debug("MY Currency: " . $MY_Currency->id() . ' ' . $MY_Currency->name() ) if $debug;
			# Now... we need to do currency conversions
			if ( $UPS_Currency->{'id'} != $MY_Currency->{'id'} ) {
				my $rate = $UPS_Currency->conversions( $MY_Currency->{'id'} );
				$cost *= $rate;
				$$specs{'hdnBreakdown'.$qty_index} .= 'Converting to ' . $MY_Currency->name() . ' using ' .$rate."\%\n";
			} # end if
			my %ServicePrice = openprint::service::get_price_object( $log, $dbh, $variable, 'UPS Shipping', $cost, undef );
			if ( $ServicePrice{'Price'} > 0 ) {
				$ServicePrice{'Total'} = $ServicePrice{'Price'};
			} else {
				$ServicePrice{'Total'} = $cost * (1 + $ServicePrice{'Markup'}/100);
			} # end if

			$$specs{"txtPrice$qty_index"} = sprintf( '%.2f', $ServicePrice{'Total'} );
		} # end if pickuptype and servicetype

	} # end foreach qty_index

	$log->debug("UPS!!!!!!!!!!!!!!!!!!");
	return $status;
} # end sub calc

sub display {
    my ( $log, $dbh, $variable, $project_index, $service_index ) = @_;
$log->debug("UPS::display: $project_index, $service_index");

	my $Project = new openprint::Project( $project_index );
	$$variable{'Project'} = $Project;
	$$variable{'txtQuantity1'} = $Project->quantity1() if ! exists $$variable{'txtQuantity1'};
	$$variable{'txtQuantity2'} = $Project->quantity2() if ! exists $$variable{'txtQuantity2'};
	$$variable{'txtQuantity3'} = $Project->quantity3() if ! exists $$variable{'txtQuantity3'};
	$$variable{'Mode'} = $Project->mode();
	$$variable{'ServiceTypeID'} = 'UPS';

	if ( $openprint::session{'company_id'} and ( ! ( 
		$$variable{'ToCity'} and $$variable{'ToPostalCode'} and $$variable{'ToStateProvince'} and $$variable{'ToCountry'} ) ) ) {
		my %shipping_fields = (
				'ToAddress1'		=>	'Address1',
				'ToAddress2'		=>	'Address2',
				'ToCity'           =>  'City',
				'ToStateProvince'  =>  'StateProvince',
				'ToCountry'        =>  'Country',
				'ToPostalCode'     =>  'PostalCode',
				);

		my $company = new openprint::obj_customer( $log, $dbh, $openprint::session{'company_id'} );
		@$variable{ keys %shipping_fields } = $company->load_shipping( @shipping_fields{ keys %shipping_fields } );
	} # end if

} # end sub display
#
sub summary {
	my ( $Project, $service_id, $specs, $qty_index ) = @_;
	if ( $qty_index ) {
		return sprintf( qq{%d items in %d package%s\nWeighing %.2flbs}, @$specs{'txtQuantity'.$qty_index,'txtPackageQuantity'.$qty_index},( $$specs{'txtPackageQuantity'.$qty_index}==1?'' : 's'), $$specs{'txtTotalWeight'.$qty_index} );
	} else {
		return join("\n", 
			join(',', ups::get_service_name($$specs{'ddmServiceType'}),ups::get_pickup_name($$specs{'ddmPickupType'}) ),
			join(',', $$specs{'ToCompanyName'} ) ,
			join(',', $$specs{'ToAddress1'} , $$specs{'ToAddress2'},
			@$specs{'ToCity','ToStateProvince','ToCountry'},
			@$specs{'ToPostalCode'} ),
			);
	} # end if
} # end sub summary

1;

__END__
