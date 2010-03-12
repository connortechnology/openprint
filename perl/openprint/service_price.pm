package openprint::service_price;
@ISA = qw(openprint::price);
use strict;

require openprint::logs;

sub save {
	my $self = shift;

	if ( ! $self->{Price} ) {
		$self->{Price} = $self->{Cost} * ( 1 + $self->{Markup}/100 );
	} # end if

	sql::insert( $self->{log}, $self->{dbh}, 'Service_Prices',
		'pricelist_id',		$self->{group}->{list_index},
		'service_id',		$self->{group}->{product_index},
		'equipment_id',		$self->{equipment_index},
		'supplier_id',		$$self{'supplier_id'},
		'min',				( $self->{min} eq '' ? undef : $self->{min} ),
		'max',				( $self->{max} eq '' ? undef : $self->{max} ),
		'units',			( $self->{units} eq '' ? undef : $self->{units} ),
		'cost',				( $self->{Cost} eq '' ? undef : $self->{Cost} ),
		'markup',			( $self->{Markup} eq '' ? undef : $self->{Markup} ),
		'price',			( $self->{Price} eq '' ? undef : $self->{Price} ),
		'discountable',		( $self->{Discountable} eq '' ? 'Y' : $self->{Discountable} )
	);
} # end sub save

1;

__END__
~       
