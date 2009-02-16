package openprint::PaymentType;
@ISA = qw(openprint::Object);

use strict;

require sql;

%fields = (
	'id'			=>	'id',
	'name'			=>	'name',
	'description'	=>	'description',
);

sub find {
	my %params = @_;

	my $sql = 'SELECT * FROM PaymentTypes WHERE 1>0';
	my @values;

	if ( $params{'name'} ) {
		$sql .= ' AND name=?';
		push @values, $params{'name'};
	} # end if
	$sql .= " ORDER BY $params{'order'}" if $params{'order'};
	my $data = $openprint::dbh->selectall_arrayref( $sql, {Slice=>{}}, @values );
	if ( ! $data ) {
		$openprint::log->debug("openprint::PaymentType::find( $sql)" . $openprint::dbh->errstr);
	} else {
		return map { new openprint::PaymentType( $_->{id}, $_ ); } @$data;
	} # end if
} # end sub find

sub load {
	my ( $self, $data ) = @_;

	if ( (! $data) and $$self{'id'} ) {
		$data = $openprint::dbh->selectrow_hashref( 'SELECT * FROM PaymentTypes WHERE id=?', {}, $$self{'id'} );
		if ( ! $data ) { $openprint::log->debug($openprint::dbh->errstr ); }
	} # end if
	@$self{keys %fields} = @$data{keys %fields};

} # end sub load

sub delete {
	my $self = shift;
    sql::execute( undef, undef, q{DELETE FROM PaymentTypes WHERE id=?}, $$self{'id'} );
} # end sub delete

sub save {
	my ( $self, $param ) = @_;

	if ( ! $$self{'id'} ) {
		@$self{'id'} = sql::execute( undef, undef, q{SELECT nextval('paymenttypes_id_seq')});
		sql::insert( undef, undef, 'PaymentTypes', $self );
	} else {
		sql::update( undef, undef, 'PaymentTypes', ['id=?', $$self{'id'}], $self );
	} # end if
} # end sub save

sub copy {
	my $self = shift;
	my $new = new openprint::PaymentType();
	@$new{keys %$self} = @$self{keys %$self};
	$$new{'id'} = undef;
	return $new;
} # end sub

1;

__END__
~       
