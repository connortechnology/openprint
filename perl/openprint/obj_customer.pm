package openprint::obj_customer;

use strict;

require openprint::address;
require openprint::Pricelist;
require openprint::logs;

my %fields = (
	'Name'				=>	'strName',
	'AccountNumber'		=>	'strAccountNum',
	'Address1'			=>	'strAddress1',
	'Address2'			=>	'strAddress2',
	'City'				=>	'strCity',
	'StateProvince'		=>	'strProvState',
	'PostalCode'		=>	'strPostalCode',
	'Country'			=>	'strCountry',
	'Phone'				=>	'strPhone',
	'Extension'			=>	'strExt',
	'Fax'				=>	'strFax',
	'MailingList'		=>	'ysnMailingList',
	'LegalForm'			=>	'LegalForm',
	'LegalBusinessName'	=>	'strLegalBusName',
	'BusinessType'		=>	'strBusinessType',
	'BusinessNature'	=>	'strBusinessNature',
	'BusinessStartDate'	=>	'dtmBusinessStartDate',
	'PresidentOwner'	=>	'strPresidentOwner',
	'Employees'			=>	'strEmployees',
	'AnnualSales'		=>	'strAnnualSales',
	'TaxNumber1'		=>	'strGSTNumber',
	'TaxNumber2'		=>	'strPSTNumber',
	'TaxExempt1'		=>	'ysnGSTExempt',
	'TaxExempt2'		=>	'ysnPSTExempt',
	'BankName'			=>	'strBankName',
	'BankBranch'		=>	'strBankBranch',
	'BankAccountNumber'	=>	'strBankAccountNo',
	'BankAccountManager'	=>	'strBankAccountManager',
	'BankPhone'			=>	'strBankPhone',
	'BankFax'			=>	'strBankFax',
	'BankEmail'			=>	'strBankEmail',
	'PriceList'			=>	'lngPriceList',
	'Currency'			=>	'currency_id',
	'Discount'			=>	'dblPricingPercent',
	'SalesPerson'		=>	'lngSalesPerson',
	'AccountActivation'	=>	'ysnAccountActivation',
	'AccountTypes'		=>	'strAccountType',
	'Reseller'			=>	'ysnReseller',
	'Supplier'			=>	'ysnSupplier',
	'CustomGreeting'	=>	'strCustomGreeting',
	'Website'			=>	'strWebURL',	
	'notes'				=>	'notes',
	'deleted'			=>	'deleted',
); # end %fields

my %transforms = (
	'Name'			=>	[ 
	's/\.//g', 
	's/^\s+//',
	's/\s+$//',
],
	'PostalCode'	=>	[ 'tr/[a-z]/[A-Z]/', 's/[\W]//g' ],
	'Discount'		=>	[ 's/[^\d\.\-]//g' ],
	'TaxNumber1'	=>	[ 's/[\D]//g', 's/(\d\d\d\d\d\d\d\d\d\d\d\d\d\d\d).*/$1/' ],
	'TaxNumber2'	=>	[ 's/[\D]//g', 's/(\d\d\d\d\d\d\d\d\d).*/$1/' ],
	'BusinessStartDate'	=>	[ 's/[^\d\-]//g' ],
);

my %defaults = (
	'Discount'		=>	'0',
	'PriceList'		=>	undef,
	'Currency'		=>  undef,
	'SalesPerson'	=>	undef,
	'AccountActivation'	=>	'N',
	'Reseller'	=>	'N',
	'Supplier'	=>	'N',
	'deleted'		=>	0,
);

sub new {
	my ( $parent, $log, $dbh, $index ) = @_;
	my $self = {};
	bless $self;
	$self->{log} = $log;
	$self->{dbh} = $dbh;

	if ( $index ) {
		$self->{index} = $index;
	} # end if
	return $self;
} # end sub new

sub get {
	my $self = shift;
	my @requested_fields = @_;

	my @get_fields = ();

	foreach my $field ( @requested_fields ) {
		if ( defined $fields{$field} ) {
			if ( defined $self->{values}->{$field} ) { 
				# means we have already loaded the value for this one
			} else {	
				# need to load it	
				push @get_fields, $field;
			} # end if	
		} else {
			$self->{log}->warn("Customer::Get::Invalid field requested: ($field)." );
		} # end if
	} # end foreach	

	# Load in the needed fields
	$self->load_values( @get_fields );
	my $values = $self->{values};
	return @$values{@requested_fields};
} # end sub get

sub load_values {
	my ( $self, @get_fields ) = @_;
	my $values = $self->{values};

	if ( @get_fields and $self->{index} ) {
		my @db_fields = @fields{@get_fields};
		if ( @db_fields ) {
		$_ = "SELECT " . join( ',',@fields{@get_fields}) . " FROM Company WHERE Index = '" . $self->{index} . "'";
		@$values{@get_fields} = sql::execute( $self->{log}, $self->{dbh}, $_ );
		} else {
			$$self{'log'}->warn("Company->load_values(@get_fields) No fields to get.");
		} # end if
	} # end if

} # end sub load_values

# if we have previously loaded info for this customer, and it hasn't changed, that field will not be saved.
# If we have not previously loaded the info, we will just save it whether it has actually changed or not.
# We do this for efficiency's sake.	
sub set {
	my ( $self, $params ) = @_;
	my @set_fields = ();
	my $values = $self->{values};

	foreach my $field ( keys %{$params} ) {
		if ( defined $fields{$field} ) {

			foreach my $transform ( @{$transforms{$field}} ) {
				eval '$$params{$field} =~ ' . $transform .';';
			} # end foreach

			if ( $params->{$field} eq '' and exists $defaults{$field} ) {
				$params->{$field} = $defaults{$field};
			} # end if

			# if valid db field
			if ( ! defined $values->{$field} or $values->{$field} ne $params->{$field} ) {
				# Only make changes to fields that have changed
				$values->{$field} = $params->{$field};	# update cache
				push @set_fields, $fields{$field}, $params->{$field};	#mark for sql updating
			} # end if
		} else {
			$self->{log}->warn("Customer::Set::Invalid field requested: ($field)." );
		} # end if
	} # end foreach

	if ( @set_fields ) {
		if ( ! $self->{index} ) {
			$_ = "SELECT nextval('CompanyIndex_seq')";
			( $self->{index} ) = sql::execute( $self->{log}, $self->{dbh}, $_ );
			sql::insert( $self->{log}, $self->{dbh}, 'Company', 'Index', $self->{index}, 'dtmDateEntered', 'NOW', @set_fields );

         # Add record to audit log - action "New Company Profile".
         openprint::logs::insertLogRecord('68', "ID: " . $self->{index} . " Name: " . $params->{'Name'},);
		} else {
			sql::update( $self->{log}, $self->{dbh}, 'Company', 'Index = '.$self->{index}, 'dtmLastModified', 'NOW', @set_fields );

         # Add record to audit log - action "Update Company Profile".
         openprint::logs::insertLogRecord('69', "ID: " . $self->{index} . " Name: " . $params->{'Name'},);
		} # end if

	} # end if

} # end sub get

sub get_shipping_address {
	my $self = shift;

	my ( $address_index ) = sql::execute( @$self{'log', 'dbh'}, "SELECT MAX(lngIndex) FROM tbl_Addresses WHERE Company_id=$self->{index}" );
	my $address = new openprint::address( $self->{log}, $self->{dbh}, $address_index, $self->{index} );
	return $address;
} # end sub get_shipping_address

sub save_shipping {
	my ( $self, $params ) = @_;

	my $address = $self->get_shipping_address();
	$address->set( $params );
} # end sub save_shipping

sub load_shipping {
	my ( $self, @params ) = @_;

	my $address = $self->get_shipping_address();
	return $address->get( @params );
} # end sub save_shipping

sub get_customer_dropdown {
    my ( $log, $dbh, $selected ) = @_;
	return openprint::Company::get_dropdown( $selected );
}	

1;

__END__

