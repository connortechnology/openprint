use strict;
package openprint::service_price;
our @ISA = qw(openprint::price);

sub save {
	my $self = shift;

	if ( ! $self->{price} ) {
		$self->{price} = $self->{cost} * ( 1 + $self->{markup}/100 );
	} # end if

	sql::insert( $self->{log}, $self->{dbh}, 'Service_Prices',
		'pricelist_id',		$self->{group}->{list_index},
		'service_id',		$self->{group}->{product_index},
		'equipment_id',		$self->{equipment_id},
		'supplier_id',		$$self{'supplier_id'},
		'period_start',		( $self->{period_start} eq '' ? undef : $self->{period_start} ),
		'period_end',				( $self->{period_end} eq '' ? undef : $self->{period_end} ),
		'min',				( $self->{min} eq '' ? undef : $self->{min} ),
		'max',				( $self->{max} eq '' ? undef : $self->{max} ),
		'units',			( $self->{units} eq '' ? undef : $self->{units} ),
		'cost',				( $self->{cost} eq '' ? undef : $self->{cost} ),
		'markup',			( $self->{markup} eq '' ? undef : $self->{markup} ),
		'price',			( $self->{price} eq '' ? undef : $self->{price} ),
		'discountable',		( $self->{discountable} eq '' ? 'Y' : $self->{discountable} )
	);
} # end sub save

sub set {
	@{$_[0]}{'self','equipment_id','period_start','period_end','min','max','units','cost','markup','price','discountable'} = @_;
} # end sub set

1;
__END__
