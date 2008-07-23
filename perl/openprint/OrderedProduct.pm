package openprint::OrderedProduct;
@ISA=qw(openprint::Object);

use strict;
require openprint::Product;
require openprint::Project;

my @fields = (
	'id',
	'order_id',
	'product_id',
	'project_id',
	'quantity',
	'price',
	'shipping_type',
	'requested_for',
	'gst',
	'hst',
	'pst',
);

sub find {
	my %params = @_;
	my $sql = 'SELECT * FROM Ordered_Products WHERE 1>0';
	my @values;

	if ( $params{'id'} ) {
		$sql .= ' AND id=?';
		push @values, $params{id};
	} # end if

	if ( $params{order_id} ) {
		$sql .= ' AND order_id=?';
		push @values, $params{order_id};
	} # end if
	if ( $params{product_id} ) {
		$sql .= ' AND product_id=?';
		push @values, $params{product_id};
	} # end if
	
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug('Error (' . $openprint::dbh->errstr . ") Loading Ordered Products: $sql @values");
		return;
	} else {
		$openprint::log->debug("Loading Ordered Products: $sql @values #results:" . @$data);
		return map { new openprint::OrderedProduct( $_->{id}, $_ ) } @$data;
	} # end if
	
} # end sub find

sub delete {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
	sql::execute( undef, undef, 'DELETE FROM ORdered_products WHERE id=?', $$self{'id'} );
	$self->Project()->delete() if $$self{'project_id'};
	sql::end_transaction( $openprint::dbh, $ac );
	return;
} # end sub delete

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Ordered_Products WHERE order_id=? AND product_id=?', {}, @$self{'order_id','product_id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub save {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('ordered_product_id_seq')});
		if ( my $e = sql::insert( undef, undef, 'Ordered_Products', map { $_, $$self{$_} } @fields ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
    } else {
        if ( my $e = sql::update( undef, undef, 'Ordered_Products', ['id=?', $$self{'id'}], map { $_, $$self{$_} } @fields ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
    } # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return;
} # end sub save

sub Project {
	my ( $self ) = @_;
	if ( $$self{'project_id'} ) {
		return new openprint::Project( $_[0]{'project_id'} );
	} else {
		my $Project = new openprint::Project( $self->Product()->project_id() )->copy();
		$Project->reference( $self->Product()->name() );
		$Project->company_id( $openprint::session{'company_id'} );
		$Project->save();
		$$self{'project_id'} = $Project->id();
		$self->save();
		return $Project;
	} # end if
} # end sub Project

sub Product {
	my $self = shift;
	return new openprint::Product( $$self{'product_id'} );
} # end sub Product

sub price {
	my $self = shift;

	if ( ! $$self{price} ) {
		my %Price = $self->Product()->get_price( $$self{quantity} );
		$$self{price} = $Price{Price};
	} # end if
	return $$self{price};
} # end sub price

1;
__END__
