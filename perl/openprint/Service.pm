package openprint::Service;
@ISA = qw( openprint::Object );
use strict;
use vars qw(%fields %transforms %defaults);

require sql;
require openprint::Object;
require openprint::pricing;
require openprint::logs;

%fields = (
		'id'				=>	'id',
		'name'				=>	'name',
		'description'		=>	'description',
		'supplier_id'		=>	'supplier_id',
		'category_id'		=>	'category_id',
		'taxexempt1'		=>	'taxexempt1',
		'taxexempt2'		=>	'taxexempt2',
		);	

%transforms = (
		);

%defaults = (
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

	if ( $params ) {
		$self->set( $params );
		$openprint::log->debug("Set params");
	} # end if

	if ( $$self{'category'} and ! $$self{'category_id'} ) {
		$_ = new openprint::ServiceCategory();
		$_->save({'name'=>$$self{'category'}});
		$$self{'category_id'} = $_->id();
	} # end if

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
	$self->load();
	return;

} # end sub save

sub delete {
	my $self = shift;

	delete $openprint::Object::cache{'openprint::Service'}{$$self{id}} if $openprint::Object::cache{'openprint::Service'};	

	my $ac = sql::start_transaction( $openprint::dbh );
    sql::execute( undef, undef, q{DELETE FROM Service_Prices WHERE service_id=?}, $$self{id} );
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
    my ( $self, $quantity, $Equipment, $Pricelist ) = @_;

	if ( ! $Pricelist ) {
		$Pricelist = new openprint::Pricelist( openprint::pricing::get_pricelist_id( $openprint::log, $openprint::dbh, $openprint::variable ));
	} # end if
    my %price = openprint::pricing::get_best_price_object( $openprint::log, $openprint::dbh, $openprint::session{'company_id'}, $$self{id}, $$Pricelist{'id'}, 'openprint::service_priceset', $quantity, $$Equipment{'id'} );
    return if ! %price;

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

sub category {
    my ( $self, $category ) = @_;

    if ( defined $category ) {
        $category =~ s/^\s*(.*)\s*$/$1/;
		@$self{'category_id','category'} = sql::execute( undef, undef, q{SELECT id, name FROM Service_Categories WHERE lower(name)=?}, lc $category );
		if ( ! $$self{'category_id'} ) {
			$$self{'category'} = $category;
		} # end if
    } elsif ( $$self{'category_id'} and ! $$self{'category'} ) {
        $$self{'category'} = new openprint::ServiceCategory( $$self{'category_id'} )->name();
    } # end if
    return $$self{'category'};
} # end sub category


1;
__END__
