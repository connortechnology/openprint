package openprint::Service;
@ISA = qw( openprint::Object );
use strict;

require sql;
require openprint::Object;
require openprint::pricing;
require openprint::logs;

my %fields = (
		'id'				=>	'id',
		'name'				=>	'name',
		'description'		=>	'description',
		'supplier_id'		=>	'supplier_id',
		'category_id'		=>	'category_id',
		'taxexempt1'		=>	'taxexempt1',
		'taxexempt2'		=>	'taxexempt2',
		);	

my %transforms = (
		);

my %defaults = (
		'supplier_id'	=>	undef,
		'category_id'	=>	undef,
		'taxexempt1'	=>	'N',
		'taxexempt2'	=>	'N',
		);

my %cache;

sub init_cache {
	%cache = map { $_->name(), $_->id() } find();
} # end sub init_cache

sub load {
	my ( $self, $data ) = @_;

	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Services WHERE id=?', {}, $$self{'id'} );
    } # end if
    @$self{keys %$data} = @$data{keys %$data};

} # end sub load

sub save {
	my ( $self, $params ) = @_;

	my $change = 1;

	if ( $params ) {
		$change = 0;
		foreach my $field ( keys %fields ) {
			foreach my $transform ( @{$transforms{$field}} ) {
				eval '$params->{$field} =~ ' . $transform;
			} # end foreach
$openprint::log->debug("FIeld: $field" );
			if ( ( ( ! defined $$params{$field} ) or ( $$params{$field} eq '' ) ) and exists $defaults{$field} ) {
$openprint::log->debug("Setting default for $field to $defaults{$field}" );
				$$params{$field} = $defaults{$field};
			} # end if

# if valid db field
			if ( ( ! defined $$self{$field} ) or ( $$self{$field} ne $$params{$field} ) ) {
# Only make changes to fields that have changed
				$$self{$field} = $$params{$field};  # update cache
				$change = 1;
			} # end if
		} # end foreach
	} # end if

	if ( $change ) {
		my %sql;
		foreach my $k ( keys %fields ) {
			$sql{$k} = $$self{$k};
		} # end foreach

		my $ac = sql::start_transaction( $openprint::dbh );
		if ( ! $$self{'id'} ) {
			@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('ServiceIndex_seq')} );
			$sql{id} = $$self{id};
			if ( my $error = sql::insert( undef, undef, 'Services', \%sql ) ) {
				sql::end_transaction( $openprint::dbh, $ac );
				return $error;
			} # end if
			openprint::logs::insertLogRecord('25', "Service Index: ". $$self{id},);
		} else {
			if ( my $error = sql::update( undef, undef, 'Services', ['id=?',$$self{id}], \%sql ) ) {
				sql::end_transaction( $openprint::dbh, $ac );
				return $error;
			} # end if
			openprint::logs::insertLogRecord('26', "Service Index: ". $self->{index},);
		} # end if
		sql::end_transaction( $openprint::dbh, $ac );
	} # end if
	$self->load();
	return;

} # end sub save

sub delete {
	my $self = shift;

	delete $openprint::Object::cache{'openprint::Service'}{$$self{id}} if $openprint::Object::cache{'openprint::Service'};	

	my $ac = sql::start_transaction( $openprint::dbh );
    sql::execute( undef, undef, q{DELETE FROM tbl_Service_Prices WHERE lngServiceIndex=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM Services WHERE id=?}, $$self{id} );
	openprint::logs::insertLogRecord('10', "Service Index: " . $$self{id},);
	sql::end_transaction( $openprint::dbh, $ac );
} # end sub delete

sub prices {
	my $self = shift;

	return openprint::ServicePrice::find( 'service_id'=>$$self{id} );
} # end sub prices

sub find {
	my %params = @_;
	my $sql = 'SELECT * FROM Services WHERE 1>0';
	my @values;

	if ( $params{'name'} ) {
		# cache optimisation, if we are looking up just by name, then we can do a quick idnex lookup
		if ( ( keys %params ) == 1 ) {
			if ( %cache and $cache{$params{name}} ) {
				return ( new openprint::Service( $cache{$params{name}} ) );
			} # end if
		} # end if
		$sql .= ' AND name=?';
		push @values, $params{'name'};
	} # end if
	if ( $params{category_id} ) {
		$sql .= ' AND category_id=?';
		push @values, $params{category_id};
	} # end if
	if ( $params{'category'} ) {
		$sql .= ' AND category_id=(SELECT id FROM Service_Categories WHERE name=?)';
		push @values, $params{'category'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	$sql .= " LIMIT $params{'limit'}" if $params{'limit'};
	
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug("Error loading Service ($sql) (@values) Reason: " . $openprint::dbh->errstr );
		return;
	} # end if
	return map { new openprint::Service( $_->{id}, $_ ) } @$data;
} # end sub find

sub get_price {
    my ( $self, $quantity, $equipment ) = @_;

    if ( ref $equipment eq 'openprint::Equipment' ) {
        $equipment = $equipment->id();
    } # end if

    my $list_id = openprint::pricing::get_pricelist_id( $openprint::log, $openprint::dbh, $openprint::variable );
    my %price = openprint::pricing::get_best_price_object( $openprint::log, $openprint::dbh, $openprint::session{'company_id'}, $$self{id}, $list_id, 'openprint::service_priceset', $quantity, $equipment );
    return if ! %price;

    my $Pricelist = new openprint::Pricelist( $list_id );
	$price{'currency_id'} = $Pricelist->currency_id();
	openprint::Currency::convert( \%price );
    return %price;
} # end sub get_price

sub next {
	my ($self, $params) = shift;
	my $sql = q{SELECT min(name) FROM Services WHERE name > ?};
	my @values = ($$self{'name'});
	if ( $params and $$params{category_id} ) {
		$sql .= ' AND category=?';
		push @values, $$params{category_id};
	} # end if
    my ($name) = sql::execute( undef, undef, $sql, @values );
	( $_ ) = sql::execute( undef, undef, q{SELECT id FROM Services WHERE name=?}, $name );
    return $_;
} # end sub next

sub Next {
	my ($self, $params) = shift;
	return new openprint::Service( $self->next($params) );
} # end sub Next

sub prev {
    my ( $self, $params ) = shift;
	my $sql = q{SELECT max(name) FROM Services WHERE name < ?};
	my @values = ($$self{'name'});
	if ( $params and $$params{category_id} ) {
		$sql .= ' AND category=?';
		push @values, $$params{category_id};
	} # end if
    my ($name) = sql::execute( undef, undef, $sql, @values );
	( $_ ) = sql::execute( undef, undef, q{SELECT id FROM Services WHERE name=?}, $name );
    return $_;
} # end sub next

sub Previous {
	my ($self, $params) = shift;
	return new openprint::Service( $self->prev($params) );
} # end sub Next
# Returns a copy of the paper object.
# Will also save the data to db
sub copy {
	my $self = shift;
	my $new = new openprint::Service( );
	@$new{keys %fields} = @$self{keys %fields};
	delete $$new{id};
	$$new{'name'} = 'Copy of ' . $$new{'name'};

	return $new;
} # end sub copy


1;
__END__
