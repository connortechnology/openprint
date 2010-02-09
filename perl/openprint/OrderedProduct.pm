package openprint::OrderedProduct;
@ISA=qw(openprint::Object);

use strict;
require openprint::Product;
require openprint::Project;
require openprint::Order;

use vars qw( $serial $table $log $dbh %fields %transforms %defaults );

my $debug = 1;

$serial = 'ordered_product_id_seq';
$table = 'ordered_products';

%fields = (
	'id' => 'id',
	'order_id' => 'order_id',
	'product_id' => 'product_id',
	'project_id'	=> 'project_id',
	'quantity'		=> 'quantity',
	'price'			=> 'price',
	'shipping_type'	=> 'shipping_type',
	'requested_for'	=> 'requested_for',
	'gst'			=> 'gst',
	'hst'			=> 'hst',
	'pst'			=> 'pst',
);

sub find {
	my %params = @_;
	my $sql = 'SELECT * FROM Ordered_Products WHERE 1>0';
	my @values;

	if ( $params{'id'} ) {
		$sql .= ' AND id=?';
		push @values, $params{id};
	} # end if

	if ( exists $params{'order_id'} ) {
		if ( $params{'order_id'} ) {
			$sql .= ' AND order_id=?';
			push @values, $params{'order_id'};
		} elsif ( ! defined $params{'order_id'} ) {
			$sql .= ' AND order_id IS NULL';
		} # end if
	} # end if
	if ( $params{'product_id'} ) {
		$sql .= ' AND product_id=?';
		push @values, $params{'product_id'};
	} # end if
	if ( $params{'project_id'} ) {
		$sql .= ' AND project_id=?';
		push @values, $params{'project_id'};
	} # end if
	
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug('Error (' . $openprint::dbh->errstr . ") Loading Ordered Products: $sql @values");
		return;
	} elsif ( $debug ) {
		$openprint::log->debug("Loading Ordered Products: $sql @values #results:" . @$data);
	} # end if
	return map { new openprint::OrderedProduct( $_->{id}, $_ ) } @$data;
	
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

sub copy {
	my ( $self ) = @_;
	my $New = new openprint::OrderedProduct();
	@$New{ keys %fields} = @$self{keys %fields};
	delete $$New{'id'};
	delete $$New{'project_id'};
	return $New;
} # end sub copy

sub Project {
	my ( $self ) = @_;
	if ( $$self{'project_id'} ) {
		return new openprint::Project( $$self{'project_id'} );
	} # end if
$openprint::log->debug("Creating proejct from template: " . $self->Product()->project_id() );
	my $Project = new openprint::Project( $self->Product()->project_id() )->copy();
	$Project->reference( $self->Product()->name() );
	$Project->user_id( $openprint::session{'user_id'} );
	$Project->company_id( $openprint::session{'company_id'} );
	$Project->currency_id( $self->Order()->currency_id() );
	$Project->save();
	$$self{'project_id'} = $Project->id();
	my $e = $self->save();
	$openprint::log->error( $e ) if $e;
	return $Project;
} # end sub Project

sub Order {
	return new openprint::Order( $_[0]{'order_id'} );
} # end sub Order

sub Product {
	my $self = shift;
	return new openprint::Product( $$self{'product_id'} );
} # end sub Product

sub price {
	my ( $self, $new_price ) = @_;
	
	if ( defined $new_price ) {
		$$self{'price'} = $new_price;
	} elsif ( ! $$self{price} ) {
		my %Price = $self->Product()->get_price( $$self{quantity} );
		$$self{price} = $Price{Price};
	} # end if
	return $$self{price};
} # end sub price

1;
__END__
