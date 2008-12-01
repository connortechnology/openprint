package openprint::Company;
@ISA = qw( openprint::Object );
use strict;
use Text::Unaccent;

use vars qw( $table $serial %fields %defaults %transforms );
use openprint ();

require sql;
require openprint::Object;
require openprint::User;

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
		);
%transforms = (
	'name' => [ 's/\.//g' ],
	'established'	=> [ 's/[^\d\-]//g' ],
);
%defaults = (
	'detail_level'	=>	undef,
	'discount'	=>	0,
	'created_on'	=> 'NOW()',
	'updated_on'	=> 'NOW()',
	'currency_id'	=>	undef,
	'pricelist_id'	=>	undef,
	'activation'	=>	'N',
	'mailinglist'	=>	'N',
	'annual_sales'	=>	undef,
	'employees'		=>	undef,
	'salesrep_id'	=>	undef,
);

my $debug = 1;

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	my $sql;
	my @values;
	$sql = q{SELECT * FROM Companies WHERE 1>0};

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
		$sql .= q{ AND name=?};
		push @values, $params{'Name'};
	} # end if
	if ( exists $params{'name'} ) {
		$sql .= q{ AND name=?};
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
	foreach my $Payment ( openprint::Payment::find('recipient_id'=>$$self{id}) ) {
		$Payment->delete();
	} # end foreach Payment
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
	sql::execute( undef, undef, 'DELETE FROM Companies WHERE id=?',$$self{'id'} );

	sql::end_transaction( $openprint::dbh, $ac );

   # Add record to audit log - action "Delete Company Profile".
   openprint::logs::insertLogRecord('5', "Company ID: $$self{'id'}");
} # end sub delete
sub save {
    my ($self, $param) = @_;
	
	$self->set( $param ) if $param;
	my %sql;
	foreach my $k ( keys %fields ) {
		$sql{$fields{$k}} = $$self{$k};
	} # end foreach
	$sql{'updated_on'} = 'NOW()';
	delete $sql{'created_on'};
	$sql{'name'} = Text::Unaccent::unac_string('LATIN1', $sql{'name'} );

    my $ac = sql::start_transaction( $openprint::dbh );
    if ( ! $$self{'id'} ) {
        @$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('companies_id_seq')} );
		$sql{id} = $$self{'id'};
        if ( my $e = sql::insert( undef, undef, 'Companies', \%sql ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
	} elsif ( $$params{'force_insert'} ) {
        if ( my $e = sql::insert( undef, undef, 'Company', \%sql ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
    } else {
        if ( my $e = sql::update( undef, undef, 'Companies', ['id=?', $$self{'id'}], \%sql ) ) {
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

	my $sql = 'SELECT id, name FROM Companies';
	my @values;

	if ( $openprint::session{'user_type'} ne 'A' and ! openprint::usergroup::is_user_in( ['Estimating','Prepress','Accounting','Shipping','Inventory'], $openprint::session{'user_id'} ) ) {
		$sql .= ' WHERE id=(SELECT company_id FROM users WHERE id=?) OR salesrep_id IN ('. join(',', $openprint::session{'user_id'}, new openprint::User( $openprint::session{'user_id'} )->csr_ids() ) .')';
		push @values, $openprint::session{'user_id'};
	} # end if
	$sql .= ' ORDER BY lower(name)';

    my @company = sql::execute( undef, undef, $sql, @values );

    return ssi::make_drop_down( \@company, $selected );
} # sub get_dropdown

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

sub Pricelist {
	my $self = shift;
	if ( $$self{'pricelist_id'} ) {
		return new openprint::Pricelist( $$self{'pricelist_id'} );
	} else {
		return new openprint::Pricelist( openprint::pricing::get_pricelist_id( $openprint::log, $openprint::dbh, $openprint::variable ));
	} # end if
} # end sub Pricelist

sub start_month {
	$_[0]{'established'} =~ /^(\d+)-(\d+)-(\d+)/;
	return $2;
} # end sub start_month
sub start_year {
	$_[0]{'established'} =~ /^(\d+)-(\d+)-(\d+)/;
	return $1;
} # end sub start_year

sub AccountingContacts {
	my ( $self ) = @_;

	return openprint::User::find('id'=>[sql::execute(undef,undef,'SELECT user_id FROM companies_accountingcontacts WHERE company_id=?',$$self{'id'} )] );
} # end sub AccountingContacts

1;
__END__
