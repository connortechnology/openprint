package openprint::material_price;
@ISA = qw(openprint::price);
use strict;

require openprint::logs;

sub save {
	my $self = shift;

	if ( ! $self->{Price} ) {
		$self->{Price} = $self->{Cost} * ( 1 + $self->{Markup}/100 );
	} # end if


	sql::insert( $self->{log}, $self->{dbh}, 'tbl_Material_Prices',
		'lngListIndex',			$self->{group}->{list_index},
		'lngMaterialIndex',		$self->{group}->{product_index},
		'lngEquipmentIndex',	$self->{equipment_id},
		'lngMin',				( $self->{min} eq '' ? undef : $self->{min} ),
		'lngMax',				( $self->{max} eq '' ? undef : $self->{max} ),
		'strUnits',				( $self->{units} eq '' ? undef : $self->{units} ),
		'dblCost',				( $self->{cost} eq '' ? undef : $self->{cost} ),
		'dblMarkup',			( $self->{markup} eq '' ? undef : $self->{markup} ),
		'dblPrice',				( $self->{price} eq '' ? undef : $self->{price} ),
		'ysnDiscountable',      ( $self->{discountable} eq '' ? 'Y' : $self->{discountable} )

	);
	
	# Add record to audit log - action "Update Material".
	openprint::logs::insertLogRecord('44', "List Index: " . $self->{group}->{list_index} . " Material Index: " . $self->{group}->{product_index},);
} # end sub save

1;

__END__
~       
