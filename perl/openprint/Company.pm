package openprint::Company;
@ISA = qw( openprint::Object );
use strict;
use Text::Unaccent;

use vars qw( %fields %defaults %transforms );
use openprint ();

require sql;
require openprint::Object;
require openprint::User;

%fields = (
		'id'						=>	'index',
		'name'						=>	'strname',
		'address1'					=>	'straddress1',
		'address2'					=>	'straddress2',
		'city'						=>	'strcity',
		'country'					=>	'strcountry',
		'state'						=>	'strprovstate',
		'postalcode'				=>	'strpostalcode',
		'salesrep_id' 				=>	'lngsalesperson',
		'pst_exempt'				=>	'ysnpstexempt',
		'gst_exempt'				=>	'ysngstexempt',
		'gst_number'				=>	'strgstnumber',
		'pst_number'				=>	'strpstnumber',
		'supplier'					=>	'ysnsupplier',
		'reseller'					=>	'ysnreseller',
		'accountnumber'				=>	'straccountnum',
		'phone'						=>	'strphone',
		'extension'					=>	'strext',
		'fax'						=>	'strfax',
		'pricelist_id'				=>	'lngpricelist',
		'currency_id'				=>	'currency_id',
		'url'						=>	'strweburl',
		'discount'					=>	'dblpricingpercent',
		'activation'				=>	'ysnaccountactivation',
		'greeting'					=>	'strcustomgreeting',
		'mailinglist'				=>	'ysnmailinglist',
		'business_type'				=>	'strbusinesstype',
		'business_name'				=>	'strlegalbusname',
		'business_form'				=>	'legalform',
		'established'				=>	'dtmbusinessstartdate',
		'president_owner'			=>	'strpresidentowner',
		'created_on'				=>	'dtmdateentered',
		'updated_on'				=>	'dtmlastmodified',
		'employees'					=>	'stremployees',
		'annual_sales'				=>	'strannualsales',
		'bank_name'					=>	'strbankname',
		'bank_branch'				=>	'strbankbranch',
		'bank_account'				=>	'strbankaccountno',
		'bank_manager'				=>	'strbankaccountmanager',
		'bank_phone'				=>	'strbankphone',
		'bank_fax'					=>	'strbankfax',
		'bank_email'				=>	'strbankemail',
		'detail_level'				=>	'detail_level',
		'quote_project_breakdown'	=>	'quote_project_breakdown',
		);
%transforms = (
	'name' => [ 's/\.//g' ],
);
%defaults = (
	'discount'	=>	0,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'currency_id'	=>	undef,
	'pricelist_id'	=>	undef,
	'activation'	=>	'N',
	'mailinglist'	=>	'N',
);

my $debug = 1;

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	my $sql;
	my @values;
	$sql = q{SELECT * FROM Company WHERE 1>0};

	if ( $params{'id'} ) {
        if ( ref $params{'id'} eq 'ARRAY' ) {
            $sql .= q{ AND index IN (}.join(',', map {'?'} @{$params{'id'}} ).')';
            push @values, @{$params{'id'}};
        } else {
            $sql .= q{ AND index=?};
            push @values, $params{'id'};
        } # end if
    } # end if

	if ( $params{'Name'} ) {
		$sql .= q{ AND strName=?};
		push @values, $params{'Name'};
	} # end if
	if ( exists $params{'name'} ) {
		$sql .= q{ AND strName=?};
		push @values, $params{'name'};
	} # end if
	if ( exists $params{'postalcode'} ) {
		$sql .= q{ AND strPostalCode=?};
		push @values, $params{'postalcode'};
	} # end if
	if ( $params{'SalesPerson'} ) {
		if ( ref $params{'SalesPerson'} eq 'ARRAY' ) {
			if ( @{$params{'SalesPerson'}} == 1 ) {
				$sql .= q{ AND lngSalesPerson=?};
			} elsif ( @{$params{'SalesPerson'}} ) {
				$sql .= q{ AND lngsalesperson IN (}.join(',', map {'?'} @{$params{'SalesPerson'}} ).')';
			} # end if
            push @values, @{$params{'SalesPerson'}};
		} else {
		$sql .= q{ AND lngSalesPerson=?};
		push @values, $params{'SalesPerson'};
		} # end if
	} # end if
	if ( $params{'salesrep_id'} ) {
		if ( ref $params{'salesrep_id'} eq 'ARRAY' ) {
			if ( @{$params{'salesrep_id'}} == 1 ) {
				$sql .= q{ AND lngSalesPerson=?};
			} elsif ( @{$params{'salesrep_id'}} ) {
				$sql .= q{ AND lngsalesperson IN (}.join(',', map {'?'} @{$params{'salesrep_id'}} ).')';
			} # end if
            push @values, @{$params{'salesrep_id'}};
		} else {
			$sql .= q{ AND lngSalesPerson=?};
			push @values, $params{'salesrep_id'};
		} # end if
	} # end if
	if ( $params{'marketing_category_id'} ) {
		$sql .= q{ AND Index IN (SELECT company_id FROM companies_in_marketing_categories WHERE category_id=?)};
		push @values, $params{'marketing_category_id'};
	} # end if
	if ( $params{'supplier'} ) {
		$sql .= ' AND ysnSupplier=?';
		push @values, $params{'supplier'};
	} # end if
	if ( $params{'reseller'} ) {
		$sql .= ' AND ysnReseller=?';
		push @values, $params{'reseller'};
	} # end if
	$sql .= " OR $params{'or'}" if $params{'or'};
	$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );

	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->error("Error Loading Companies: ($sql) (@values): " . $openprint::dbh->errstr );
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Companies: ($sql) (@values) :" . @$data );
	} # end if
	return map { new openprint::Company( $_->{index}, $_ ) } @$data;
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Company WHERE Index=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->warn("Error loading company $$self{id} " . $openprint::dbh->errstr() ); }
	} # end if
	@$self{keys %fields} = @$data{@fields{keys %fields}};
} # end sub load

sub Currency {
	my $self = shift;
	return new openprint::Currency( $$self{'currency_id'} );
} # end sub CUrrency

sub delete {
	my $self = shift;
	my $ac = sql::start_transaction( $openprint::dbh );
# i'm not sure why we did this, for now we are going to delete the users
#sql::update( undef, undef, 'Company_Users', "CompanyIndex = '$index'", 'lngCustomerID', 0 );
	sql::execute( undef, undef, 'DELETE FROM Trade_References WHERE Company_id =?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM HelpDesk WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM RMA WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Company_Credit WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM CreditApplications WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Companies_in_Marketing_Categories WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Payments WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Complaints WHERE company_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM survey_responses WHERE company_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM log WHERE company_id=?', $$self{'id'} );

	foreach my $Paper ( openprint::Paper::find('owner_id'=>$$self{'id'} ) ) {
		$Paper->delete();
	} # end foreach

	foreach my $Quote ( openprint::Quote::find('company_id'=>$$self{'id'} ) ) {
		$Quote->delete();	
	} # end foreach
	foreach my $Order ( openprint::Order::find('company_id'=>$$self{'id'} ) ) {
		$Order->delete();	
	} # end foreach
	sql::execute( undef, undef, 'DELETE FROM Order_log WHERE Company_Id=?', $$self{'id'} );
	foreach my $Project ( openprint::Project::find('company_id'=>$$self{'id'} ) ) {
		$Project->delete();	
		last if $openprint::dbh->errstr();
	} # end foreach
	sql::execute( undef, undef, 'DELETE FROM Project_log WHERE Company_Id=?', $$self{'id'} );
	foreach my $User ( openprint::User::find('company_id'=>$$self{'id'} ) ) {
		$User->delete();
	} # end foreach
	sql::execute( undef, undef, 'DELETE FROM Company WHERE Index=?',$$self{'id'} );

	sql::end_transaction( $openprint::dbh, $ac );

   # Add record to audit log - action "Delete Company Profile".
   openprint::logs::insertLogRecord('5', "Company ID: $$self{'id'}");
} # end sub delete
sub save {
    my ( $self, $params ) = @_;
	my %sql;
	foreach my $k ( keys %fields ) {
		my @transforms = @{$transforms{$k}} if $transforms{$k};
		foreach my $transform ( @transforms ) {
			eval '$$self{$k} =~ ' . $transform;
		} # end foreach

		if ( ( ( ! defined $$self{$k} ) or ( $$self{$k} eq '' ) ) and exists $defaults{$k} ) {
			$openprint::log->debug("Setting default for $k $defaults{$k}");
			$sql{$fields{$k}} = $defaults{$k};
		} else {
			$sql{$fields{$k}} = $$self{$k};
		} # end if
	} # end foreach
	$sql{dtmlastmodified} = 'NOW()';
	$sql{'strname'} = Text::Unaccent::unac_string('LATIN1', $sql{'strname'} );

    my $ac = sql::start_transaction( $openprint::dbh );
    if ( ! $$self{'id'} ) {
        @$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('CompanyIndex_seq')} );
		$sql{index} = $$self{'id'};
        if ( my $e = sql::insert( undef, undef, 'Company', \%sql ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
	} elsif ( $$params{'force_insert'} ) {
        if ( my $e = sql::insert( undef, undef, 'Company', \%sql ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
    } else {
        if ( my $e = sql::update( undef, undef, 'Company', ['index=?', $$self{'id'}], \%sql ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
    } # end if

    $self->load();
    sql::end_transaction( $openprint::dbh, $ac );
	return;

} # end sub save

sub next {
    my $self = shift;

    ( $_ ) = sql::execute( undef, undef, 'SELECT Index FROM Company WHERE strName = ( SELECT MIN(strName) FROM Company WHERE strName > (SELECT strName FROM Company WHERE Index=? ) )', $$self{id} );
    return $_;
} # end sub next

sub prev {
    my $self = shift;
    ( $_ ) = sql::execute( undef, undef, 'SELECT Index FROM Company WHERE strName = ( SELECT MAX(strName) FROM Company WHERE strName < (SELECT strName FROM Company WHERE Index=? ) )', $$self{id} );
    return $_;
} # end sub prev

sub set {
	my ( $self, $params ) = @_;
	my @set_fields = ();

	foreach my $field ( keys %{$params} ) {
		
		if ( defined $fields{$field} ) {
			my @transforms = @{$transforms{$field}} if $transforms{$field};

			foreach my $transform ( @transforms ) {
				eval '$params->{$field} =~ ' . $transform;
			} # end foreach

			if ( ( ( ! defined $$params{$field} ) or ( $$params{$field} eq '' ) ) and exists $defaults{$field} ) {
$openprint::log->debug("Setting default for $field $defaults{$field}");
				$$params{$field} = $defaults{$field};
			} # end if

# if valid db field
			if ( ( ! defined $$self{$field} ) or ($$self{$field} ne $$params{$field}) ) {
# Only make changes to fields that have changed
				$$self{$field} = $$params{$field};
				push @set_fields, $fields{$field}, $$params{$field};	#mark for sql updating
			} # end if
		} # end if
	} # end foreach
	return @set_fields;
} # end sub set

sub load_tradereferences {
	my ( $self, $index, $hash ) = @_;

	@$hash{
		'tradereference'.$index.'_companyname',
			'tradereference'.$index.'_contact',
			'tradereference'.$index.'_phone',
			'tradereference'.$index.'_ext',
			'tradereference'.$index.'_fax',
			'tradereference'.$index.'_email',
			'tradereference'.$index.'_creditlimit',
			} = sql::execute( undef, undef, 
        'SELECT CompanyName, Contact, Phone, Ext, Fax, Email, CreditLimit FROM Trade_References WHERE company_id = ? AND ID = ?', $$self{id}, $index );
} # end load_tradereferences

sub save_tradereferences {
	my ( $self, $param ) = @_;

	my $ac = sql::start_transaction( $openprint::dbh );
    sql::execute( undef, undef, 'DELETE FROM Trade_References WHERE company_id=?', $$self{id} );
	foreach my $tr ( 1 .. 3 ) {
		my %sql = (
			'CompanyName'	=>	$$param{'tradereference'.$tr.'_companyname'},
			'Contact'		=>	$$param{'tradereference'.$tr.'_contact'},
			'Phone'			=>	$$param{'tradereference'.$tr.'_phone'},
			'Ext'			=>	$$param{'tradereference'.$tr.'_ext'},
			'Fax',			=>	$$param{'tradereference'.$tr.'_fax'},
			'Email',		=>	$$param{'tradereference'.$tr.'_email'},
			'CreditLimit'	=>	$$param{'tradereference'.$tr.'_creditlimit'},
			'company_id'	=>	$$self{id},
			'id'			=>	$tr,
			);

		sql::insert( undef, undef, 'Trade_References', \%sql );
	} # end foreach
	sql::end_transaction( $openprint::dbh, $ac );
	return;
} # end sub save_tradereferences

sub start_year {
	my $self = shift;
	$$self{'established'} =~ /(\d\d\d\d)-(\d\d)-(\d\d)/;
	return $1;
} # end sub start_year

sub Credit {
	my ( $self, $supplier ) = @_;
	
	return new openprint::customer_credit( $$self{id}, $supplier );
} # end sub Credit
sub get_dropdown {
	my $selected = shift;

	my $sql = 'SELECT Index, strName FROM Company';
	my @values;

	if ( $openprint::session{'user_type'} ne 'A' and ! openprint::usergroup::is_user_in( ['Estimating','Prepress','Accounting','Shipping','Inventory'], $openprint::session{'user_id'} ) ) {
		$sql .= ' WHERE Index=(SELECT CompanyIndex FROM Users WHERE Index=?) OR lngSalesPerson IN ('. join(',', $openprint::session{'user_id'}, new openprint::User( $openprint::session{'user_id'} )->csr_ids() ) .')';
		push @values, $openprint::session{'user_id'};
	} # end if
	$sql .= ' ORDER BY lower(strname)';

    my @company = sql::execute( undef, undef, $sql, @values );

    return ssi::make_drop_down( \@company, $selected );
} # sub get_customer_dropdown

sub CSR {
	my $self = shift;
	return new openprint::User( $$self{'salesrep_id'} );
}

sub Users {
	my $self = shift;
	return openprint::User::find('company_id'=>$$self{'id'} );
} # end sub Users
sub taxexempt1 {
	return $_[0]{gst_exempt};
}
sub taxexempt2 {
	return $_[0]{pst_exempt};
}

1;
__END__
