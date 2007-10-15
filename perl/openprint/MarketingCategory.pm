package openprint::MarketingCategory;
@ISA = qw( openprint::Object );
use strict;

require sql;

my @fields = (
	'id',
	'name',
	'description',
	'greeting',
);

# Returns a paper object specified by the parameters
sub find {
	my %params = @_;

	if ( $params{'id'} ) {
		return new openprint::MarketingCategory( $params{'id'} );
	} else {
		my $sql;
		my @values;
		$sql = q{SELECT * FROM Marketing_Categories WHERE 1>0};

		if ( $params{'Name'} ) {
			$sql .= q{ AND strName=?};
			push @values, $params{'Name'};
		} # end if
		if ( $params{'company_id'} ) {
			$sql .= ' AND id IN (SELECT category_id FROM Companies_in_Marketing_Categories WHERE company_id=?)';
			push @values, $params{'company_id'};
		} # end if
		if ( $params{'user_id'} ) {
			$sql .= ' AND id IN (SELECT category_id FROM Users_in_Marketing_Categories WHERE user_id=?)';
			push @values, $params{'user_id'};
		} # end if
		$sql .= " OR $params{'or'}" if $params{'or'};
		$sql .= " ORDER BY $params{'order'}" if ( $params{'order'} );

		my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
		if ( ! $data ) {
			$openprint::log->debug("Error loading Marketing Categories: ($sql)".DBI->errstr );
			return;
		} elsif ( ! @$data ) {
			$openprint::log->debug("No Marketing Categories: ($sql)".DBI->errstr );
			return;
		} # end if
		return map { new openprint::MarketingCategory( $_->{id}, $_ ) } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;
$openprint::log->debug("Marketing Category load");
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( q{SELECT * FROM Marketing_Categories WHERE id=?}, {}, $$self{'id'} );
        if ( ! $data ) {
            $openprint::log->error( "Failure to load Marketing Cateogry $$self{'id'}: Reason: " . $openprint::dbh->errstr );
            return;
        } # end if
    } # end if
    foreach my $key ( keys %{$data} ) {
        $$self{$key} = $$data{$key};
    } # end foreach
} # end sub load

sub save {
	my ( $self, $data ) = @_;

	my %sql;
	foreach ( @fields ) {
		$$self{$_} = $$data{$_} if $$data{$_};
		$sql{$_} = $$self{$_};
	} # end foreach
	
	if ( ! $$self{'id'} ) {
		($$self{'id'}) = ($sql{'id'}) = sql::execute( undef, undef, q{SELECT nextval('Marketing_Category_id_seq')} );
		sql::insert( undef, undef, 'Marketing_Categories', \%sql );
	} else {
		sql::update( undef, undef, 'Marketing_Categories', "id=$$self{id}", \%sql );
	} # end if
	$self->load();
} # end sub save

sub delete {
	my $self = shift;
	my $ac = sql::start_transaction();
	sql::execute( undef, undef, q{DELETE FROM Companies_in_Marketing_Categories WHERE category_id=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM Users_in_Marketing_Categories WHERE category_id=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM Marketing_Categories WHERE id=?}, $$self{id} );
	sql::end_transaction( $ac );
} # end sub delete

sub next {
	my $self = shift;
	return new openprint::MarketingCategory( sql::execute( undef, undef, q{SELECT MIN(id) FROM Marketing_Categories WHERE id > ?}, $$self{id} ) );
} # end sub next;
sub previous {
	my $self = shift;
	return new openprint::MarketingCategory( sql::execute( undef, undef, q{SELECT MIN(id) FROM Marketing_Categories WHERE id > ?}, $$self{id} ) );
} # end sub previous

sub companies {
	my ( $self, %params ) = @_;
	$params{'marketing_category_id'} = $$self{'id'};
	return openprint::Company::find( %params );
} # end sub companies

sub add_company {
	my $self = shift;
	if ( @_ == 1 ) {
		my $company = shift;
		if ( ref $company eq 'openprint::Company' ) {
			sql::execute( undef, undef, q{DELETE FROM Companies_In_Marketing_Categories WHERE category_id=? AND company_id=?}, $$self{'id'}, $company->id() );
			sql::insert( undef, undef, 'Companies_In_Marketing_Categories', 'category_id', $$self{'id'}, 'company_id', $company->id() );
		} elsif ( ref $company eq 'ARRAY' ) {
			foreach ( @$company ) { $self->remove_company( $_ ); } # end foreach
		} else {
			# assume that it is a company_id
			sql::execute( undef, undef, q{DELETE FROM Companies_In_Marketing_Categories WHERE category_id=? AND company_id=?}, $$self{'id'}, $company );
			sql::insert( undef, undef, 'Companies_In_Marketing_Categories', 'category_id', $$self{'id'}, 'company_id', $company );
		} # end if
	} elsif ( @_ > 1 ) {
		foreach ( @_ ) { $self->remove_company( $_ ); } # end foreach
	} # end if
} # end sub add_company

sub remove_company {
	my $self = shift;
	if ( @_ == 1 ) {
		my $company = shift;
		if ( ref $company eq 'openprint::Company' ) {
			sql::execute( undef, undef, q{DELETE FROM Companies_In_Marketing_Categories WHERE category_id=? AND company_id=?}, $$self{'id'}, $company->id() );
		} elsif ( ref $company eq 'ARRAY' ) {
			foreach ( @$company ) { $self->remove_company( $_ ); } # end foreach
		} else {
			# assume that it is a company_id
			sql::execute( undef, undef, q{DELETE FROM Companies_In_Marketing_Categories WHERE category_id=? AND company_id=?}, $$self{'id'}, $company );
		} # end if
	} elsif ( @_ > 1 ) {
		foreach ( @_ ) { $self->remove_company( $_ ); } # end foreach
	} # end if
} # end sub remove_company

1;
__END__
