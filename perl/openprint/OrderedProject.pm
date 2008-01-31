package openprint::OrderedProject;
@ISA=qw(openprint::Object);

use strict;
require openprint::Project;

my @fields = (
	'id',
	'order_id',
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
	my $sql = 'SELECT * FROM Order_Contents WHERE 1>0';
	my @values;

	if ( $params{order_id} ) {
		$sql .= ' AND orderindex=?';
		push @values, $params{order_id};
	} # end if
	if ( $params{product_id} ) {
		$sql .= ' AND projectindex=?';
		push @values, $params{project_id};
	} # end if
	
	my $data = $openprint::dbh->selectall_arrayref( $sql, { Slice => {} }, @values );
	if ( ! $data ) {
		$openprint::log->debug('Error (' . $openprint::dbh->errstr . ") Loading Ordered Projects: $sql @values");
		return;
	} else {
		$openprint::log->debug("Loading Ordered Projects: $sql @values #results:" . @$data);
		return map { new openprint::OrderedProject( $_->{id}, $_ ) } @$data;
	} # end if
	
} # end sub find

sub load {
	my ( $self, $data ) = @_;
	if ( ! $data ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM Ordered_Projects WHERE orderindex=? AND projectindex=?', {}, @$self{'order_id','project_id'} );
	} # end if
	@$self{keys %$data} = @$data{keys %$data};
} # end sub load

sub save {
	my $self = shift;

	my $ac = sql::start_transaction( $openprint::dbh );
	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('ordered_project_id_seq')});
		if ( my $e = sql::insert( undef, undef, 'Ordered_Projects', map { $_, $$self{$_} } @fields ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
    } else {
        if ( my $e = sql::update( undef, undef, 'Ordered_Projects', ['id=?', $$self{'id'}], map { $_, $$self{$_} } @fields ) ) {
			$openprint::dbh->rollback();
			return $e;
		} # end if
    } # end if
	sql::end_transaction( $openprint::dbh, $ac );
	$self->load();
	return;
} # end sub save

sub Project {
	my $self = shift;
	return new openprint::Project( $$self{'project_id'} );
} # end sub Project

sub price {
	my $self = shift;

	if ( ! $$self{price} ) {
		my %Price = $self->Project()->get_price( $$self{quantity} );
		$$self{price} = $Price{Price};
	} # end if
	return $$self{price};
} # end sub price

1;
__END__
