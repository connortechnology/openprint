package openprint::service_priceset;
@ISA = qw(openprint::priceset);

use strict;

require openprint::service_price;

sub save {
	my $self = shift;

	$_ = "DELETE FROM tbl_Service_Prices WHERE lngServiceIndex='" . $self->{product_index} . "'\n".
		"AND lngListIndex = '" . $self->{list_index} .  "'\n";
	$_ .= "AND lngEquipmentIndex = '".$self->{equipment_index}."'\n" if $self->{equipment_index};
	$_ .= "AND ($self->{qty} :: numeric >= lngMin OR lngMin isNull) AND ($self->{qty} :: numeric <= lngMax OR lngMax isNull)" if $self->{qty};
	sql::execute( $self->{log}, $self->{dbh}, $_ );

	foreach my $price ( @{$self->{prices}} ) {
		$price->save();
	} # end foreach
}

sub load {
	my $self = shift;

	my @values = ( @$self{'product_index','list_index'} );
    my $sql = 'SELECT lngEquipmentIndex, lngMin, lngMax, strUnits, dblCost, dblMarkup, dblPrice, ysnDiscountable FROM tbl_Service_Prices WHERE lngServiceIndex=? AND lngListIndex=?';
	if ( $self->{equipment_index} ) {
		$sql .= ' AND (lngEquipmentIndex=? OR lngEquipmentIndex IS NULL)';
		push @values, $self->{equipment_index};
	} # end if
	if ( $self->{qty} ) {
		$sql .= ' AND (? >= lngMin OR lngMin isNull) AND (? <= lngMax OR lngMax isNull)';
		push @values, @$self{'qty','qty'};
	} # end if
    my @records = sql::execute( 0, undef, $sql, @values );
    while ( @records ) {
		my $price = openprint::service_price->new( $self->{log}, $self->{dbh}, $self );
		$price->set( splice @records, 0, 8 );
		push @{$self->{prices}}, $price;
    } # end while
}

1;

__END__
~       
