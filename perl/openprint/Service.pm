package openprint::Service;
@ISA = qw( openprint::Object );
use strict;
use vars qw($table $serial %fields %transforms %defaults %session $log $dbh );

require sql;
require openprint::Object;
require openprint::pricing;
require openprint::logs;
use openprint ();
*session = \%openprint::session;
*log = \$openprint::log;
*dbh = \$openprint::dbh;

my $debug = 1;

$table = 'services';
$serial = 'services_id_seq';

%fields = (
		'id'				=>	'id',
		'name'				=>	'name',
		'description'		=>	'description',
		'supplier_id'		=>	'supplier_id',
		'category_id'		=>	'category_id',
		'taxexempt1'		=>	'taxexempt1',
		'taxexempt2'		=>	'taxexempt2',
		'owner_id'			=>	'owner_id',
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

sub save {
	my ( $self, $params ) = @_;

	$self->set( $params );

	if ( $$self{'category'} and ! $$self{'category_id'} ) {
		$_ = new openprint::ServiceCategory();
		$_->save({'name'=>$$self{'category'}});
		$$self{'category_id'} = $_->id();
	} # end if
	$$self{'owner_id'} = $session{'company_id'} if ! $$self{'owner_id'};

	if ( ( my $error = $self->SUPER::save( ) ) ) {
		return $error;
	} # end if
	return;

} # end sub save

sub delete {
	my $self = shift;

	delete $openprint::Object::cache{'openprint::Service'}{$$self{id}} if $openprint::Object::cache{'openprint::Service'};	
	delete $cache{$$self{name}};
	my $ac = sql::start_transaction( $dbh );
    sql::execute( undef, undef, q{DELETE FROM Service_Prices WHERE service_id=?}, $$self{id} );
	sql::execute( undef, undef, q{DELETE FROM Services WHERE id=?}, $$self{id} );
	openprint::logs::insertLogRecord('10', "Service Index: " . $$self{id},);
	sql::end_transaction( $dbh, $ac );
	return $dbh->errstr();
} # end sub delete

sub prices {
	my $self = shift;

	return openprint::ServicePrice->find( 'service_id'=>$$self{id} );
} # end sub prices

sub find {
	my $self = shift;
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
	if ( $params{'name_like'} ) {
		$sql .= ' AND name LIKE ?';
		push @values, $params{'name_like'};
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
	
	my $data = $dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$log->debug("Error loading Service ($sql) (@values) Reason: " . $dbh->errstr );
		return;
	} elsif ( $debug ) {
		$log->debug("Loading Service ($sql) (@values) " . @$data );
	} # end if
	return map { new openprint::Service( $_->{id}, $_ ) } @$data;
} # end sub find

sub get_price {
    my ( $self, $quantity, $Equipment, $Pricelist ) = @_;

	if ( ! $Pricelist ) {
		$Pricelist = new openprint::Pricelist( openprint::pricing::get_pricelist_id( $log, $dbh, $openprint::variable ));
	} # end if
    my %price = openprint::pricing::get_best_price_object( $log, $dbh, $openprint::session{'company_id'}, $$self{id}, $$Pricelist{'id'}, 'openprint::service_priceset', $quantity, $$Equipment{'id'} );
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
