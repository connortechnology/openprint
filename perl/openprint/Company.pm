use strict;
package openprint::Company;
our @ISA = qw( openprint::Object );

use vars qw( $debug $log $dbh $table $serial %fields %find_fields %defaults %transforms );
require openprint;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

require sql;
require openprint::Object;
require openprint::User;

$debug = 0;
$table = 'companies';
$serial = 'companies_id_seq';

%fields = (
		'id'						=>	'id',
		'name'						=>	'name',
		'address1'					=>	'address1',
		'address2'					=>	'address2',
		'city'						=>	'city',
		'country'					=>	'country',
		'state'						=>	'state',
		'postalcode'				=>	'postalcode',
		'salesrep_id' 				=>	'salesrep_id',
		'pst_exempt'				=>	'ysnpstexempt',
		'gst_exempt'				=>	'ysngstexempt',
		'gst_number'				=>	'fedtaxnumber',
		'pst_number'				=>	'statetaxnumber',
		'supplier'					=>	'ysnsupplier',
		'reseller'					=>	'ysnreseller',
		'accountnumber'				=>	'straccountnum',
		'phone'						=>	'phone',
		'extension'					=>	'strext',
		'fax'						=>	'fax',
		'pricelist_id'				=>	'pricelist_id',
		'currency_id'				=>	'currency_id',
		'url'						=>	'url',
		'discount'					=>	'discount',
		'activation'				=>	'ysnaccountactivation',
		'greeting'					=>	'greeting',
		'mailinglist'				=>	'mailinglist',
		'business_type'				=>	'business_type',
		'business_name'				=>	'business_name',
		'business_form'				=>	'business_form',
		'established'				=>	'established',
		'president_owner'			=>	'president_owner',
		'created_on'				=>	'created_on',
		'updated_on'				=>	'updated_on',
		'employees'					=>	'employees',
		'annual_sales'				=>	'annual_sales',
		'bank_name'					=>	'bank_name',
		'bank_branch'				=>	'bank_branch',
		'bank_account'				=>	'bank_account',
		'bank_manager'				=>	'bank_manager',
		'bank_phone'				=>	'bank_phone',
		'bank_fax'					=>	'bank_fax',
		'bank_email'				=>	'bank_email',
		'detail_level'				=>	'detail_level',
		'quote_project_breakdown'	=>	'quote_project_breakdown',
		'notes'						=>	'notes',
		'deleted'					=>	'deleted',
		'category_id'				=>	'category_id',
		'offers_credit'				=>	'offers_credit',
		);
%find_fields = (
	last_online	=>	'(SELECT MAX(date_time) FROM Logs WHERE company_id=companies.id)',
	marketing_category_id	=>	'(SELECT category_id FROM companies_in_marketing_categories WHERE company_id=companies.id)',
);
%transforms = (
	'established'	=> [ 's/[^\d\-]//g' ],
	'name' => [ 's/[\.\,]//g', 's/^\s+//', 's/\s+$//','s/\///g' ],
	'discount'	=>	[ 's/[^\d\.\-]//g' ],
);
%defaults = (
	'detail_level'	=>	undef,
	'discount'	=>	0,
	'created_on'	=> q`'NOW()'`,
	'updated_on'	=> q`'NOW()'`,
	'currency_id'	=>	undef,
	'pricelist_id'	=>	undef,
	'activation'	=>	q`'N'`,
	'mailinglist'	=>	q`'N'`,
	'annual_sales'	=>	undef,
	'employees'		=>	undef,
	'salesrep_id'	=>	undef,
	'deleted'		=>	0,
	'category_id'	=>	undef,
	'offers_credit'	=>	0,
);

sub Currency {
	return new openprint::Currency( $_[0]{'currency_id'} );
} # end sub CUrrency

sub destroy {
	my $self = shift;
	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( undef, undef, 'DELETE FROM Trade_References WHERE Company_id =?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM HelpDesk WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM RMA WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Company_Credit WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM CreditApplications WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM Companies_in_Marketing_Categories WHERE Company_Id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM tbl_Addresses WHERE company_id=?', $$self{'id'} );
	foreach my $Payment ( openprint::Payment->find('recipient_id'=>$$self{id}) ) {
		$Payment->delete();
	} # end foreach Payment
	sql::execute( undef, undef, 'DELETE FROM Complaints WHERE company_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM survey_responses WHERE company_id=?', $$self{'id'} );
	sql::execute( undef, undef, 'DELETE FROM logs WHERE company_id=?', $$self{'id'} );

	foreach my $Paper ( openprint::Paper->find('owner_id'=>$$self{'id'} ) ) {
		$Paper->delete();
	} # end foreach

	foreach my $Quote ( openprint::Quote->find('company_id'=>$$self{'id'} ) ) {
		$Quote->delete();	
	} # end foreach
	foreach my $Order ( openprint::Order->find('company_id'=>$$self{'id'} ) ) {
		$Order->delete();	
	} # end foreach
	sql::execute( undef, undef, 'DELETE FROM Order_log WHERE Company_Id=?', $$self{'id'} );
	foreach my $Project ( openprint::Project->find('company_id'=>$$self{'id'} ) ) {
		$Project->delete();	
		last if $dbh->errstr();
	} # end foreach
	sql::execute( undef, undef, 'DELETE FROM Project_log WHERE Company_Id=?', $$self{'id'} );
	foreach my $User ( openprint::User->find('company_id'=>$$self{'id'}, 'deleted'=>[0,1] ) ) {
		$User->destroy();
	} # end foreach
	sql::execute( undef, undef, 'DELETE FROM Companies WHERE id=?',$$self{'id'} );

	sql::end_transaction( $dbh, $ac );

   # Add record to audit log - action "Delete Company Profile".
   new openprint::Log()->save({'action'=>'Destroy Company', 'note'=>"Company ID: $$self{id} $$self{name}"});
} # end sub destroy

sub save {
    my ($self, $param) = @_;
	
	require Text::Unaccent;
	$self->set( $param );
	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$fields{$k}} = $$self{$k};
	} # end foreach
	$sql{'updated_on'} = 'NOW()';
	$sql{'name'} = Text::Unaccent::unac_string('UTF-8', $sql{'name'} );

    my $ac = sql::start_transaction( $dbh );
    if ( ! $$self{'id'} ) {
        @$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('companies_id_seq')} );
		$sql{id} = $$self{'id'};
        if ( my $e = sql::insert( undef, undef, 'Companies', \%sql ) ) {
			$dbh->rollback();
			sql::end_transaction( $dbh, $ac );
			delete $$self{'id'};
			return $e;
		} # end if
	} elsif ( $$param{'force_insert'} ) {
        if ( my $e = sql::insert( undef, undef, 'Company', \%sql ) ) {
			$dbh->rollback();
			sql::end_transaction( $dbh, $ac );
			return $e;
		} # end if
    } else {
		delete $sql{'created_on'};
        if ( my $e = sql::update( undef, undef, 'Companies', ['id=?', $$self{'id'}], \%sql ) ) {
			$dbh->rollback();
    sql::end_transaction( $dbh, $ac );
			return $e;
		} # end if
	} # end if

    sql::end_transaction( $dbh, $ac );
    $self->load();
	return;

} # end sub save

sub next {
	my $self = shift;

    ( $_ ) = sql::execute( undef, undef, 'SELECT id FROM Companies WHERE Name = ( SELECT MIN(Name) FROM Companies WHERE Name > (SELECT Name FROM Companies WHERE id=? ) )', $$self{id} );
    return $_;
} # end sub next

sub prev {
    my $self = shift;
    ( $_ ) = sql::execute( undef, undef, 'SELECT id FROM Companies WHERE name = ( SELECT MAX(name) FROM Companies WHERE name < (SELECT name FROM Companies WHERE id=? ) )', $$self{id} );
    return $_;
} # end sub prev

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

	my $ac = sql::start_transaction( $dbh );
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
	sql::end_transaction( $dbh, $ac );
	return;
} # end sub save_tradereferences


sub Credit {
	
	my $supplier = $_[1] ? $_[1] : $openprint::config{'owner_id'};;

	require openprint::Company_Credit;
	if ( ! $_[0]{id} ) {
		$_ =  new openprint::Company_Credit();
		$_->set({supplier_id=>$supplier});
		return $_;
	} # end if
	return new openprint::Company_Credit( { 'company_id'=>$_[0]{id}, 'supplier_id'=>$supplier } );
} # end sub Credit

sub dropdown {
	shift @_ if $_[0] eq 'openprint::Company';

	my $sql = 'SELECT id, name FROM Companies WHERE (deleted=false or deleted IS NULL)';
	my @values;

	if ( $openprint::session{user_id} and ( $openprint::session{'user_type'} ne 'A' ) and ! openprint::usergroup::is_user_in( ['Estimating','Prepress','Accounting','Shipping','Inventory'], $openprint::session{'user_id'} ) ) {
		$sql .= ' AND id=(SELECT company_id FROM users WHERE id=?) OR salesrep_id IN ('. join(',', $openprint::session{'user_id'}, new openprint::User( $openprint::session{'user_id'} )->csr_ids() ) .')';
		push @values, $openprint::session{'user_id'};
	} # end if

	if ( @_ ) {
		my %params;
		if ( ref $_[0] eq 'HASH' ) {
			%params = %{$_[0]};
		} elsif ( ref $_[0] eq 'ARRAY' ) {
			%params = @{$_[0]};
		} else {
			%params = @_;
		} # end if
		if ( $params{'id'} ) {
			if ( ref $params{'id'} eq 'ARRAY' ) {
				$sql .= ' AND id IN ( '.join(',', @{$params{'id'}} ).' )';
			} # end if
		} # end if
		if ( $params{supplier} ) {
			$sql .= ' AND ysnsupplier=?';
			push @values, $params{supplier};
		} # end if
	} # end if
	$sql .= ' ORDER BY lower(name)';

	my $companies = sql::execute_array( undef, undef, $sql, @values );
	return $companies;
} # end sub dropdown

sub get_dropdown {
	shift @_ if $_[0] eq 'openprint::Company';
	my $companies = dropdown( $_[1] ? $_[1] : () );
	return $companies ? ssi::make_drop_down( $companies, $_[0] ) : '';
} # sub get_dropdown

sub CSR {
	my $self = shift;
	return new openprint::User( $$self{'salesrep_id'} );
}

sub Users {
	my $self = shift;
	my %params = @_;
	$params{'company_id'} = $$self{'id'};
	return openprint::User->find( \%params );
} # end sub Users

sub Pricelist {
	if ( $_[0]{'pricelist_id'} ) {
		return new openprint::Pricelist( $_[0]{'pricelist_id'} );
	} else {
		return new openprint::Pricelist( openprint::pricing::get_pricelist_id());
	} # end if
} # end sub Pricelist

sub start_month {
	if ( $_[0]{'established'} =~ /^(\d+)-(\d+)-(\d+)/ ) {
		return $2;
	} # end if
} # end sub start_month
sub start_year {
	if ( $_[0]{'established'} =~ /^(\d+)-(\d+)-(\d+)/ ) {
		return $1;
	} # end if
} # end sub start_year

sub AccountingContacts {
	my ( $self ) = @_;
	my @user_ids = sql::execute(undef,undef,'SELECT user_id FROM companies_accountingcontacts WHERE company_id=?',$$self{id} );

	return openprint::User->find(id=>\@user_ids) if @user_ids;
	return;
} # end sub AccountingContacts

sub get_shipping_address {
	my $self = shift;

	require openprint::address;
	my ( $address_index ) = sql::execute( undef,undef, 'SELECT MAX(lngIndex) FROM tbl_Addresses WHERE Company_id=?', $$self{id} );
	my $Address = new openprint::address( $log, $dbh, $address_index, $$self{id} );
	return $Address;
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

sub Profile {
	require openprint::Company_Profile;
	return new openprint::Company_Profile( $_[0]{'id'} );
}

sub location {
	return misc::build_city_prov_country( $_[0]->get('city','state','country') );
} # end sub location

sub can_edit {
	return 1 if $openprint::session{'user_type'} eq 'A';
	return 1 if $_[0]->salesrep_id() == $openprint::session{'user_id'};
	my $Me = new openprint::User( $openprint::session{'user_id'} );
	return 1 if sets::isin( $_[0]->salesrep_id(), $Me->csr_ids() );
	return 1 if $_[0]{'id'} == $$Me{'company_id'} and $$Me{'administrator'} eq 'Y';
} # end sub can_edit

sub taxexempt1 {
	if ( @_ > 1 ) {
		$_[0]{'taxexempt1'} = $_[1];
	} # end if
	if ( ! $_[0]{'taxexempt1'} ) {
		$_[0]{'taxexempt1'} = $_[0]{'gstnumber'} ? 'Y' : 'N';
	} # end if
	return $_[0]{'taxexempt1'};
} # end sub taxexempt1

sub taxexempt2 {
	if ( @_ > 1 ) {
		$_[0]{'taxexempt2'} = $_[1];
	} # end if
	if ( ! $_[0]{'taxexempt2'} ) {
		$_[0]{'taxexempt2'} = $_[0]{'pstnumber'} ? 'Y' : 'N';
	} # end if
	return $_[0]{'taxexempt2'};
} # end sub taxexempt2

sub address {
return join(', ', map { $_ ? $_ : () } @{$_[0]}{'address1','address2','city','state','postalcode','country'} );
} # end sub address

sub can_view_all {
	return 1 if $openprint::session{user_type} eq 'A';
	return 1 if openprint::usergroup::is_user_in( ['Estimating','Prepress','Accounting','Shipping','Inventory'], $openprint::session{'user_id'} );
	return 0;
} # end sub can_view_all

sub find_filtered {
    return if ! $openprint::session{user_id};
    return openprint::Company->find(order=>'lower(name)') if $openprint::session{user_type} eq 'A';

    my $User = new openprint::User( $openprint::session{user_id} );

    return openprint::Company->find(
        ( ! openprint::usergroup::is_user_in( ['Estimating','Prepress','Accounting','Shipping','Inventory'], $openprint::session{'user_id'} ) ? (
        salesrep_id => [ $openprint::session{user_id}, $User->csr_ids() ],
        ) : () ),
        or		=> 'id='.$User->company_id(),
        order	=>'lower(strname)',
    );
} # end sub find_filtered

sub can_view {
    return 1 if $openprint::session{'user_type'} eq 'A';
    return 1 if $_[0]->salesrep_id() == $openprint::session{'user_id'};
    my $Me = new openprint::User( $openprint::session{'user_id'} );
    return 1 if $_[0]{'id'} == $$Me{'company_id'} and $$Me{'administrator'} eq 'Y';
} # end sub can_view

1;
__END__
