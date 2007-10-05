package openprint::customer;

use strict;
require sql;
require ssi;
require misc;
require openprint::customer_credit;
require openprint::obj_customer;

sub load_tradereferences {
	my ( $r, $log, $dbh, $cust_id, $variable ) = @_;

	foreach my $tr ( 1 .. 3 ) {
		$_ = "SELECT CompanyName, Contact, Phone, Ext, Fax, Email, CreditLimit ".
			"FROM Trade_References ".
			"WHERE company_id = $cust_id AND ID = $tr";
		(
		 $$variable{'txtTradeReferenceCompanyName'.$tr},
		 $$variable{'txtTradeReferenceContact'.$tr},
		 $$variable{'txtTradeReferencePhone'.$tr},
		 $$variable{'txtTradeReferenceExt'.$tr},
		 $$variable{'txtTradeReferenceFax'.$tr},
		 $$variable{'txtTradeReferenceEmail'.$tr},
		 $$variable{'txtTradeReferenceCreditLimit'.$tr}
		) = misc::trim(sql::execute( $log, $dbh, $_ ));
	} # end foreach
} # end load_tradereferences

sub save_tradereferences {
	my ( $r, $log, $dbh, $cust_id ) = @_;

	my $commit = $dbh->{AutoCommit};
	$dbh->{AutoCommit} = 0;
	sql::execute( $log, $dbh, "DELETE FROM Trade_References WHERE company_id=$cust_id" );
# save trade references
	foreach my $tr ( 1 .. 3 ) {

		my @sql = (
			( defined $r->param('txtTradeReferenceCompanyName'.$tr) ? ( 'CompanyName', $r->param('txtTradeReferenceCompanyName'.$tr) ) : () ),
			( defined $r->param('txtTradeReferenceContact'.$tr) ? ( 'Contact',	$r->param('txtTradeReferenceContact'.$tr) ) : () ),
			( defined $r->param('txtTradeReferencePhone'.$tr) ? ( 'Phone',		$r->param('txtTradeReferencePhone'.$tr) ) : () ),
			( defined $r->param('txtTradeReferenceExt'.$tr) ? ( 'Ext',		$r->param('txtTradeReferenceExt'.$tr) ) : () ),
			( defined $r->param('txtTradeReferenceFax'.$tr) ? ( 'Fax',		$r->param('txtTradeReferenceFax'.$tr) ) : () ),
			( defined $r->param('txtTradeReferenceEmail'.$tr) ? ( 'Email',		$r->param('txtTradeReferenceEmail'.$tr) ) : () ),
			( defined $r->param('txtTradeReferenceCreditLimit'.$tr) ? ( 'CreditLimit', ( $r->param('txtTradeReferenceCreditLimit'.$tr) eq '' ? undef : $r->param('txtTradeReferenceCreditLimit'.$tr) ) ) : () )
		);

		sql::insert( $log, $dbh, "Trade_References", 'company_id', $cust_id, 'ID', $tr, @sql );
	} # end foreach
	$dbh->commit();
	$dbh->{AutoCommit} = $commit;

} # end sub save_tradereferences

my %shipping_fields = (
    'txtShippingCompanyName'    =>  'CompanyName',
    'txtShippingFirstName'      =>  'FirstName',
    'txtShippingLastName'       =>  'LastName',
    'rdbShippingSalutation'     =>  'Salutation',
    'txtShippingAddress1'       =>  'Address1',
    'txtShippingAddress2'       =>  'Address2',
    'txtShippingCity'           =>  'City',
    'ddmShippingStateProvince'  =>  'StateProvince',
    'ddmShippingCountry'        =>  'Country',
    'txtShippingPostalCode' 	=>	'PostalCode',
    'txtShippingPhone'          =>  'Phone',
    'txtShippingExtension'      =>  'Extension',
    'txtShippingFax'            =>  'Fax',
    'txtShippingEmail'          =>  'Email',
);


sub load_shipping {
	my ( $log, $dbh, $cust_id, $variable ) = @_;

	my $customer = new openprint::obj_customer( $log, $dbh, $cust_id );
	my $address = $customer->get_shipping_address();

    @$variable{ keys %shipping_fields } = ssi::htmlize( misc::trim($address->get( @shipping_fields{ keys %shipping_fields } ) ) );
} # end sub load_shipping

sub save_shipping {
	my ( $r, $log, $dbh, $cust_id ) = @_;

	my $customer = new openprint::obj_customer( $log, $dbh, $cust_id );
	my $address = $customer->get_shipping_address();

    my %params;
    foreach my $field ( keys %shipping_fields ) {
        @params{$shipping_fields{$field}} = misc::trim($r->param($field)) if defined $r->param($field);
    } # end foreach
    $address->set( \%params );

} # save_shipping

sub load {
	my ( $r, $log, $dbh, $cust_id, $variable ) = @_; 
	my $temp;

	$temp = "SELECT strAccountNum, strName, strAddress1, strAddress2, strCity, strProvState, strPostalCodeZip, strCountry, strPhone,\n".
		"strExt, strFax, strLegalBusName, LegalForm,\n".
		"strBusinessType, dtmBusinessStartdate, strPresidentOwner, strEmployees,\n".
		"strAnnualSales, strPSTNumber, strGSTNumber, ysnPSTExempt, ysnGSTExempt, strBankName, strBankBranch, strBankAccountNo, strBankAccountManager, strBankPhone,\n".
		"strBankFax, strBankEmail,\n".
		"lngPriceList, dblPricingPercent, lngSalesPerson, ysnAccountActivation, ysnSupplier, ysnReseller,\n".
		"strCustomGreeting, lngWarehouseID, strWebURL\n".
		"FROM Company WHERE Index = '$cust_id'";
		(
		$$variable{'txtAccountNum'},
		$$variable{'txtCompanyName'},
		$$variable{'txtAddress1'},
		$$variable{'txtAddress2'},
		$$variable{'txtCity'},
		$$variable{'ddmStateProvince'},
		$$variable{'txtPostalCode'},
		$$variable{'ddmCountry'},
		$$variable{'txtPhone'},
		$$variable{'txtExtension'},
		$$variable{'txtFax'},
		$$variable{'txtLegalBusinessName'},
		$$variable{'rdbLegalForm'},
		$$variable{'txtBusinessType'},
		$$variable{'txtStartDate'},
		$$variable{'txtPresidentOwner'},
		$$variable{'ddmEmployees'},
		$$variable{'ddmAnnualSales'},
		$$variable{'txtPSTNumber'},
		$$variable{'txtGSTNumber'},
		$$variable{'rdbPSTExempt'},
		$$variable{'rdbGSTExempt'},
		$$variable{'txtBankName'},
		$$variable{'txtBankBranch'},
		$$variable{'txtBankAccountNo'},
		$$variable{'txtBankAccountManager'},
		$$variable{'txtBankPhone'},
		$$variable{'txtBankFax'},
		$$variable{'txtBankEmail'},
		$$variable{'ddmPriceList'},
		$$variable{'txtPricingLevel'},
		$$variable{'ddmSalesPerson'},
		$$variable{'rdbAccountActivation'},
		$$variable{'rdbSupplier'},
		$$variable{'rdbReseller'},
		$$variable{'txtCustomGreeting'},
		$$variable{'ddmWarehouse'},
		$$variable{'txtURL'},
	) = misc::trim(sql::execute( $log, $dbh, $temp ));

	$$variable{'Country'} = $$variable{'txtCountry'} = $$variable{'ddmCountry'};
	$$variable{'StateProvince'} = $$variable{'txtStateProvince'} = $$variable{'ddmStateProvince'};
	$$variable{'txtBankAccountNumber'} = $$variable{'txtBankAccountNo'};

	my $customer_credit = new openprint::customer_credit( $cust_id );
	my %credit_fields = (
			'txtWarnDays'		=>	'WarnDays',
			'txtDenyDays'		=>	'DenyDays',
			'txtCreditLimit'	=>	'Limit',
			'rdbCreditHold'		=>	'Hold',
			'txtDownpayment'	=>	'Downpayment',
			);
	@$variable{ keys %credit_fields } = ssi::htmlize( $customer_credit->get( @credit_fields{ keys %credit_fields } ) );

} # end sub load

1;

__END__

