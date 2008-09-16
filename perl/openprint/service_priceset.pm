package openprint::service_priceset;
@ISA = qw(openprint::priceset);

use strict;

require openprint::service_price;

sub save {
	my $self = shift;

	$_ = "DELETE FROM Service_Prices WHERE service_id='" . $self->{product_index} . "'\n".
		"AND pricelist_id = '" . $self->{list_index} .  "'\n";
	$_ .= "AND equipment_id = '".$self->{equipment_index}."'\n" if $self->{equipment_index};
	$_ .= "AND ($self->{qty} :: numeric >= min OR min IS NULL) AND ($self->{qty} :: numeric <= max OR max IS NULL)" if $self->{qty};
	sql::execute( $self->{log}, $self->{dbh}, $_ );

	foreach my $price ( @{$self->{prices}} ) {
		$price->save();
	} # end foreach
}

sub load {
	my $self = shift;

	my @values = ( @$self{'product_index','list_index'} );
    my $sql = 'SELECT equipment_id, Min, Max, Units, Cost, Markup, Price, Discountable FROM Service_Prices WHERE Service_id=? AND pricelist_id=?';
	if ( $self->{equipment_index} ) {
		$sql .= ' AND (equipment_id=? OR equipment_id IS NULL)';
		push @values, $self->{equipment_index};
	} # end if
	if ( $self->{qty} ) {
		$sql .= ' AND (? >= Min OR Min IS NULL) AND (? <= Max OR Max IS NULL)';
		push @values, @$self{'qty','qty'};
	} # end if
    my @records = sql::execute( undef, undef, $sql, @values );
    while ( @records ) {
		my $price = openprint::service_price->new( $self->{log}, $self->{dbh}, $self );
		$price->set( splice @records, 0, 8 );
		push @{$self->{prices}}, $price;
    } # end while
}

1;

__END__
~       
