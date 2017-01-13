package ups;

use strict;

require XML::DOM;
use LWP::UserAgent;
use HTTP::Request;
use HTTP::Request::Common;

my %ServiceCodes = (
	'Next Day Air'			=>	'01',
	'2nd Day Air'			=>	'02',
	'Ground'				=>	'03',
	'Worldwide Express'		=>	'07',
	'Worldwide Expedited'	=>	'08',
	'Standard'				=>	'11',
	'3-Day Select'			=>	'12',
	'Next Day Air Saver'	=>	'13',
	'Next Day Air Early AM'	=>	'14',
	'Worldwide Express Plus'=>	'54',
	'2nd Day Air AM'		=>	'59',
	'Express Saver'			=>	'65',
);
my %PickupTypes = (
	'Daily Pickup'					=>	'01',
	'Customer Counter'				=>	'03',
	'One Time Pickup'				=>	'06',
	'On Call Air'					=>	'07',
	'Authorized Shipping Outlet'	=>	'11',
	'Letter Center'					=>	'19',
	'Air Service Center'			=>	'20',
);

sub get_service_codes {
	return keys %ServiceCodes;
}
sub get_pickup_types {
	return keys %PickupTypes;
}
sub get_service_code {
	return $ServiceCodes{shift @_};
}
sub get_service_name {
	my $value = shift;
	foreach ( keys %ServiceCodes ) {
		return $_ if $ServiceCodes{$_} == $value
	} # end foreach
}
sub get_pickup_type {
	return $PickupTypes{shift @_};
}
sub get_pickup_name {
	my $value = shift;
	foreach ( keys %PickupTypes ) {
		return $_ if $PickupTypes{$_} == $value
	} # end foreach
}

sub createAccessRequest {
	my ( $license, $user_id, $password ) = @_;

	my $doc = new XML::DOM::Document;
	$doc->setXMLDecl( $doc->createXMLDecl( '1.0' ) );
	my $accessrequest = $doc->appendChild($doc->createElement('AccessRequest'));

	# Access License Number
	$_ = $accessrequest->appendChild($doc->createElement('AccessLicenseNumber'));
	$_->appendChild($doc->createTextNode($license));

	# User ID
	$_ = $accessrequest->appendChild($doc->createElement('UserId'));
	$_->appendChild($doc->createTextNode($user_id)); 
	# Password
	$_ = $accessrequest->appendChild($doc->createElement('Password'));
	$_->appendChild($doc->createTextNode($password)); 

	$_ = $doc->toString();
	$doc->dispose;
	return $_;
} # end sub createAccessRequest

sub createShoppingRequest {
	my %params = @_;

    my $doc = new XML::DOM::Document;
    $doc->setXMLDecl( $doc->createXMLDecl( '1.0' ) );
	my $rssrequest = $doc->appendChild($doc->createElement('RatingServiceSelectionRequest'));
	$rssrequest->setAttribute( 'xml:lang', 'en-US' );
	$rssrequest->appendChild(createRequest($doc,'Rating and Service','Rate','shop'));

	my $shipment = $rssrequest->appendChild($doc->createElement('Shipment'));
	my $shipper = $shipment->appendChild($doc->createElement('Shipper'));
	my $address = $shipper->appendChild($doc->createElement('Address'));
	$_ = $address->appendChild($doc->createElement('PostalCode'));
	$_->appendChild($doc->createTextNode($params{'ShipperPostalCode'}));
	if ( $params{'ShipperCity'} ) {
		$_ = $address->appendChild($doc->createElement('City'));
		$_->appendChild($doc->createTextNode($params{'ShipperCity'}));
	} # end if
	if ( $params{'ShipperStateProvince'} ) {
		$_ = $address->appendChild($doc->createElement('StateProvinceCode'));
		$_->appendChild($doc->createTextNode($params{'ShipperStateProvince'}));
	} # end if
	if ( $params{'ShipperCountry'} ) {
		$_ = $address->appendChild($doc->createElement('CountryCode'));
		$_->appendChild($doc->createTextNode($params{'ShipperCountry'}));
	} # end if

	my $shipto = $shipment->appendChild($doc->createElement('ShipTo'));
	my $shipto_address = $shipto->appendChild($doc->createElement('Address'));
	$_ = $shipto_address->appendChild($doc->createElement('PostalCode'));
	$_->appendChild($doc->createTextNode($params{'ShipToPostalCode'}));
	if ( $params{'ShipToCity'} ) {
		$_ = $shipto_address->appendChild($doc->createElement('City'));
		$_->appendChild($doc->createTextNode($params{'ShipToCity'}));
	} # end if
	if ( $params{'ShipToStateProvince'} ) {
		$_ = $shipto_address->appendChild($doc->createElement('StateProvinceCode'));
		$_->appendChild($doc->createTextNode($params{'ShipToStateProvince'}));
	} # end if
	if ( $params{'ShipToCountry'} ) {
		$_ = $shipto_address->appendChild($doc->createElement('CountryCode'));
		$_->appendChild($doc->createTextNode($params{'ShipToCountry'}));
	} # end if

	if ( $params{'ServiceCode'} ) {
		my $service = $shipment->appendChild($doc->createElement('Service'));
		$_ = $service->appendChild($doc->createElement('Code'));
		$_->appendChild($doc->createTextNode($params{'ServiceType'} ? $params{'ServiceType'} : '11'));
	} # end if

	if ( $params{'Packages'} and @{$params{'Packages'}} ) {
		addPackages( $doc, $shipment, @{$params{'Packages'}} );
	} # end if
	my $shipmentserviceoptions = $shipment->appendChild($doc->createElement('ShipmentServiceOptions'));

	$_ = $doc->toString();
	$doc->dispose;
	return $_;
}

sub addPackages {
	my ( $doc, $shipment, @packages ) = @_;

	while ( @packages ) {
		my $package_info = shift @packages;

		my $package = $shipment->appendChild($doc->createElement('Package'));
		if ( $$package_info{'Length'} or $$package_info{'Width'} or $$package_info{'Height'} ) {
			my $dimensions = $package->appendChild($doc->createElement('Dimensions'));
			if ( $$package_info{'Length'} ) {
				$_ = $dimensions->appendChild($doc->createElement('Length'));
				$_->appendChild($doc->createTextNode($$package_info{'Length'}));
			} # end if
			if ( $$package_info{'Width'} ) {
				$_ = $dimensions->appendChild($doc->createElement('Width'));
				$_->appendChild($doc->createTextNode($$package_info{'Width'}));
			} # end if
			if ( $$package_info{'Height'} ) {
				$_ = $dimensions->appendChild($doc->createElement('Height'));
				$_->appendChild($doc->createTextNode($$package_info{'Height'}));
			} # end if
		} # end if
		my $packagingtype = $package->appendChild($doc->createElement('PackagingType'));
		$_ = $packagingtype->appendChild($doc->createElement('Code'));
		$_->appendChild($doc->createTextNode('02'));
		$_ = $packagingtype->appendChild($doc->createElement('Description'));
		$_->appendChild($doc->createTextNode('Package'));

		$_ = $package->appendChild($doc->createElement('Description'));
		$_->appendChild($doc->createTextNode('Rate Shopping'));

		my $packageweight = $package->appendChild($doc->createElement('PackageWeight'));
		$_ = $packageweight->appendChild($doc->createElement('Weight'));
		$_->appendChild($doc->createTextNode($$package_info{'Weight'}));
	} # end while

} # end sub createShoppingRequest

sub createRatingServiceSelectionRequest {
	my %params = @_;

    my $doc = new XML::DOM::Document;
    $doc->setXMLDecl( $doc->createXMLDecl( '1.0' ) );
	my $rssrequest = $doc->appendChild($doc->createElement('RatingServiceSelectionRequest'));
	$rssrequest->setAttribute( 'xml:lang', 'en-US' );
	$rssrequest->appendChild(createRequest($doc,'Rating and Service','Rate','rate'));

	my $pickuptype = $rssrequest->appendChild($doc->createElement('PickupType'));
	$_ = $pickuptype->appendChild($doc->createElement('Code'));
	$_->appendChild($doc->createTextNode($params{'PickupType'}));

	my $shipment = $rssrequest->appendChild($doc->createElement('Shipment'));

	my $shipper = $shipment->appendChild($doc->createElement('Shipper'));
	my $address = $shipper->appendChild($doc->createElement('Address'));
	$_ = $address->appendChild($doc->createElement('PostalCode'));
	$_->appendChild($doc->createTextNode($params{'ShipperPostalCode'}));
	if ( $params{'ShipperCity'} ) {
		$_ = $address->appendChild($doc->createElement('City'));
		$_->appendChild($doc->createTextNode($params{'ShipperCity'}));
	} # end if
	if ( $params{'ShipperStateProvince'} ) {
		$_ = $address->appendChild($doc->createElement('StateProvinceCode'));
		$_->appendChild($doc->createTextNode($params{'ShipperStateProvince'}));
	} # end if
	if ( $params{'ShipperCountry'} ) {
		$_ = $address->appendChild($doc->createElement('CountryCode'));
		$_->appendChild($doc->createTextNode($params{'ShipperCountry'}));
	} # end if

	my $shipto = $shipment->appendChild($doc->createElement('ShipTo'));
	my $shipto_address = $shipto->appendChild($doc->createElement('Address'));
	$_ = $shipto_address->appendChild($doc->createElement('PostalCode'));
	$_->appendChild($doc->createTextNode($params{'ShipToPostalCode'}));
	if ( $params{'ShipToCity'} ) {
		$_ = $shipto_address->appendChild($doc->createElement('City'));
		$_->appendChild($doc->createTextNode($params{'ShipToCity'}));
	} # end if
	if ( $params{'ShipToStateProvince'} ) {
		$_ = $shipto_address->appendChild($doc->createElement('StateProvinceCode'));
		$_->appendChild($doc->createTextNode($params{'ShipToStateProvince'}));
	} # end if
	if ( $params{'ShipToCountry'} ) {
		$_ = $shipto_address->appendChild($doc->createElement('CountryCode'));
		$_->appendChild($doc->createTextNode($params{'ShipToCountry'}));
	} # end if

	my $service = $shipment->appendChild($doc->createElement('Service'));
	$_ = $service->appendChild($doc->createElement('Code'));
	$_->appendChild($doc->createTextNode($params{'ServiceType'} ? $params{'ServiceType'} : '11'));

	if ( $params{'Packages'} and @{$params{'Packages'}} ) {
		addPackages( $doc, $shipment, @{$params{'Packages'}} );
	} # end if

	my $shipmentserviceoptions = $shipment->appendChild($doc->createElement('ShipmentServiceOptions'));

	$_ = $doc->toString();
	$doc->dispose;
	return $_;
} # end sub createRatingServiceSelectionRequest

sub createRequest {
	my ( $doc, $customer_context, $action, $option ) = @_;

	my $request = $doc->createElement('Request');

	my $transactionreference = $request->appendChild($doc->createElement('TransactionReference'));

	# CustomerContext
	$_ = $transactionreference->appendChild($doc->createElement('CustomerContext'));
	$_->appendChild($doc->createTextNode($customer_context));

	# XpciVersion
	$_ = $transactionreference->appendChild($doc->createElement('XpciVersion'));
	$_->appendChild($doc->createTextNode('1.0001'));

	# RequestAction
	$_ = $request->appendChild($doc->createElement('RequestAction'));
	$_->appendChild($doc->createTextNode($action));
	# RequestOption
	$_ = $request->appendChild($doc->createElement('RequestOption'));
	$_->appendChild($doc->createTextNode($option));

	$request->appendChild($doc->createElement('IntegrationIndicator'));

	return $request;
} # end sub createRequest

sub createTrackRequest {
	my ( $tracking ) = @_;

	my $doc = new XML::DOM::Document;
	$doc->setXMLDecl( $doc->createXMLDecl( '1.0' ) );
	my $trackrequest = $doc->appendChild($doc->createElement('TrackRequest'));
	$trackrequest->setAttribute( 'xml:lang', 'en-US' );

	$trackrequest->appendChild(createRequest($doc,'Example 1','Track','activity'));

	# Tracking Number
	$_ = $trackrequest->appendChild($doc->createElement('TrackingNumber'));
	$_->appendChild($doc->createTextNode($tracking));

	$_ = $doc->toString();
	$doc->dispose;

	return $_;
} # end sub createAccessRequest

sub sendRequest {
	my ( $log, $url, $content ) = @_;

	$ENV{HTTPS_VERSION} = 3;
#$log->debug($content);
	my $req = POST $url, Content=>$content;
#, [ 'Content-Length' => length($content)];
	#$req->content($content);

	my $ua = new LWP::UserAgent;
	my $response = $ua->request($req);
	if ( ! $response->is_success ) {
		# communications error
		$log->warn( "Communications Error: " . $response->error_as_HTML ) if $log;
	} else {
		#$log->debug( "Raw Reponse: " . $response->content );
	} # end if

#$log->debug($response->content);
	return $response->content;
} # end sub sendRequest

sub parseText {
	my $node = shift;
	my $text = '';

	foreach my $node ( $node->getChildnodes() ) {
		$text .= $node->getData();
	} # end foreach
	return $text;
} # end sub parseText

sub parseAddress {
	my ( $node ) = @_;
	my ( $city, $state, $country );

	if ( $node->getName() eq 'Address' ) {
		foreach my $node ( $node->getChildnodes() ) {
			if ( $node->getName() eq 'City' ) {
				$city = parseText($node);
			} elsif ( $node->getName() eq 'StateProvinceCode' ) {
				$state = parseText($node);
			} elsif ( $node->getName() eq 'CountryCode' ) {
				$country = parseText($node);
			} # end if
		} # end foreach
	} # end if
	return ($city, $state, $country);
} # end sub parseAddress

sub parseStatus {
	my $node = shift;
	my $status = '';

	foreach my $node ( $node->getChildnodes() ) {
		if ( $node->getName() eq 'StatusType' ) {
			foreach my $node ( $node->getChildnodes() ) {
				if ( $node->getName() eq 'Description' ) {
					$status = parseText( $node );
				} # end if
			} # end foreach
		} # end if
	} # end foreach
	return $status;	
} # end sub parseStatus

sub parseActivity {
	my ( $log, $node ) = @_;
	my ( @address, $status, $date, $time, $signed );

	foreach my $node ( $node->getChildnodes() ) {
		if ( $node->getName() eq 'ActivityLocation' ) {
			foreach my $node ( $node->getChildnodes() ) {
				if ( $node->getName() eq 'Address' ) {
					@address = parseAddress( $node );
				} elsif ( $node->getName() eq 'SignedForByName' ) {
					$signed = parseText( $node );
				} # end if
			} # end foreach
		} elsif ( $node->getName() eq 'Status' ) {
			$status = parseStatus( $node );
		} elsif ( $node->getName() eq 'Date' ) {
			$date = parseText( $node );
			$date =~ /(\d\d\d\d)(\d\d)(\d\d)/;
			$date = misc::getMonth($2).' '.$3.', '.$1;
		} elsif ( $node->getName() eq 'Time' ) {
			$time = parseText( $node );
			$time =~ /(\d\d)(\d\d)(\d\d)/;
			my $ampm;
			my $hour = $1;
			if ( $hour >= 12 ) {
				$ampm = 'pm';
				if ( $hour > 12 ) {
					$hour -= 12;
				} # end if
			} else {
				$ampm = 'am';
			} # end if
			$time = $hour.':'.$2.$ampm;

		} # end if
	} # end foreach
	return ( @address, $status, $date, $time, $signed );
} # end sub parseActivity

sub extract_tracking {
	my ( $log, $variable, $doc ) = @_;
	if ( $doc ) {
		my $root = $doc->documentElement;
		foreach my $node ( $root->getChildnodes() ) {
			if ( $node->getName() eq 'Shipment' ) {
				foreach my $node ( $node->getChildnodes() ) {
					if ( $node->getName() eq 'Service' ) {
						foreach my $node ( $node->getChildnodes() ) {
							if ( $node->getName() eq 'Description' ) {
								foreach my $node ( $node->getChildnodes() ) {
									$$variable{'ServiceType'} = $node->getData();
								} # end foreach
							} # end if
						} # end foreach
					} elsif ( $node->getName() eq 'Package' ) {
						foreach my $node ( $node->getChildnodes() ) {
							if ( $node->getName() eq 'TrackingNumber' ) {
								$$variable{'TrackingNumber'} = parseText( $node );
							} elsif ( $node->getName() eq 'Activity' ) {
								my ( $city, $state, $country, $status, $date, $time, $signed ) = parseActivity( $log, $node );
								if ( $status eq 'DELIVERED' ) {
									$$variable{'SignedBy'} = $signed;
									$$variable{'DeliveredOn'} = "$date $time";
									$$variable{'DeliveredTo'} = "$city, $state, $country";
									$$variable{'Status'} = $status;
								} # end if
								unshift @{$$variable{'Activities'}}, misc::build_city_prov_country($city, $state, $country), $status, $date, $time;
							} # end if
						} # end foreach
					} # end if
				} # end if

			} # end if
		} # end foreach
	} # end if
	if ( ! $$variable{'Status'} ) {
		$$variable{'Status'} = @{$$variable{'Activities'}}[3];
	} # end if
} # end sub extract_tracking

sub parseServiceCode {
	my ( $node ) = @_;
	foreach my $node ( $node->getChildnodes() ) {
		if ( $node->getName() eq 'Code' ) {
			return parseText( $node );
		} # end if
	} # end foreach
} # end sub parseServiceCode

sub parseCharge {
	my ( $node ) = @_;
	my ($currency, $amount);
	foreach my $node ( $node->getChildnodes() ) {
		if ( $node->getName() eq 'CurrencyCode' ) {
			$currency = parseText( $node );
		} elsif ( $node->getName() eq 'MonetaryValue' ) {
			$amount = parseText( $node );
		} # end if
	} # end foreach
	return $amount . $currency;
} # end sub parseCharge

sub parseRatedShipment {
	my ( $log, $node ) = @_;
	my ( $service, $transportcharges, $servicecharges, $totalcharges );
	foreach my $node ( $node->getChildnodes() ) {
		if ( $node->getName() eq 'Service' ) {
			$service = parseServiceCode( $node );
		} elsif ( $node->getName() eq 'TransportationCharges' ) {
			$transportcharges = parseCharge( $node );
		} elsif ( $node->getName() eq 'ServiceOptionsCharges' ) {
			$servicecharges = parseCharge( $node );
		} elsif ( $node->getName() eq 'TotalCharges' ) {
			$totalcharges = parseCharge( $node );
		} # end if
	} # end foreach
	return ( $service, $transportcharges, $servicecharges, $totalcharges );
} # end sub parseRatedShipment

sub parseError {
	my $node = shift;
	my ( $severity, $code, $description );
	foreach my $node ( $node->getChildnodes() ) {
		if ( $node->getName() eq 'ErrorSeverity' ) {
			$severity = parseText( $node );
		} elsif ( $node->getName() eq 'ErrorCode' ) {
			$code = parseText( $node );
		} elsif ( $node->getName() eq 'ErrorDescription' ) {
			$description = parseText( $node );
		} # end if
	} # end foreach
	return ( $severity, $code, $description );
} # end sub parseError

sub parseResponse {
	my $node = shift;
} # end sub parseResponse

sub extract_RSS {
	my ( $log, $variable, $doc ) = @_;
	if ( $doc ) {
		my $root = $doc->documentElement;
		foreach my $node ( $root->getChildnodes() ) {
			if ( $node->getName() eq 'RatedShipment' ) {
				my ( $service, $transportcharges, $servicecharges, $totalcharges ) = parseRatedShipment( $log, $node );
				push @{$$variable{'RatedShipments'}}, $service, $totalcharges;
			} elsif ( $node->getName() eq 'Response' ) {
				foreach my $node ( $node->getChildnodes() ) {
					if ( $node->getName() eq 'Error' ) {
						@$variable{'UPSErrorSeverity','UPSErrorCode','UPSErrorDescription'} = parseError( $node );
					} # end if
				} # end foreach
			} # end if
		} # end foreach
	} # end if
} # end sub extract_RSS
